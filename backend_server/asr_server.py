import os
import json
import sqlite3
import logging
import subprocess
import shutil
from datetime import datetime
from typing import Tuple, Dict, Optional, Union, List
from flask import Flask, request, jsonify
from flask_limiter import Limiter
from werkzeug.utils import secure_filename
from dotenv import load_dotenv
from openai import OpenAI

# Load environment variables
load_dotenv()

# Environment variables and constants
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
FLASK_SECRET_KEY = os.getenv('FLASK_SECRET_KEY')
if not OPENAI_API_KEY or not FLASK_SECRET_KEY:
    raise ValueError("Missing required environment variables: OPENAI_API_KEY, FLASK_SECRET_KEY")

SERVER_HOST = os.getenv('SERVER_HOST', '0.0.0.0')
SERVER_PORT = int(os.getenv('SERVER_PORT', '5000'))
# Set an upload size limit (adjust if needed)
MAX_FILE_SIZE = int(os.getenv('MAX_FILE_SIZE', '16777216'))
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, os.getenv('UPLOAD_FOLDER', 'uploads'))
DB_PATH = os.path.join(BASE_DIR, os.getenv('DB_PATH', 'transcripts.db'))
FFMPEG_PATH = os.getenv('FFMPEG_PATH', 'ffmpeg')
RATE_LIMIT_TRANSCRIBE = os.getenv('RATE_LIMIT_TRANSCRIBE', '10/minute')
RATE_LIMIT_LECTURE = os.getenv('RATE_LIMIT_LECTURE', '5/minute')

ALLOWED_EXTENSIONS = {'wav', 'mp3', 'ogg', 'flac', 'aac'}

# Setup Flask app and limiter
app = Flask(__name__)
app.secret_key = FLASK_SECRET_KEY
limiter = Limiter(app)

# Ensure upload folder exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("asr_server.log"),
        logging.StreamHandler()
    ]
)

# Initialize OpenAI client
client = OpenAI(api_key=OPENAI_API_KEY)

def init_db() -> None:
    """Initialize the transcripts table."""
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute('''
            CREATE TABLE IF NOT EXISTS transcripts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                text TEXT NOT NULL,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                filename TEXT
            )
        ''')

def init_mini_lecture_db() -> None:
    """Initialize the mini_lectures table."""
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute('''
            CREATE TABLE IF NOT EXISTS mini_lectures (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                transcript_id INTEGER NOT NULL,
                lecture_data TEXT NOT NULL,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (transcript_id) REFERENCES transcripts(id)
            )
        ''')

init_db()
init_mini_lecture_db()

def allowed_file(filename: str) -> bool:
    """Check if the file has an allowed extension."""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def validate_upload_file(file) -> Optional[Tuple[Dict, int]]:
    """Validate uploaded file before processing."""
    if file.filename == '':
        return {"error": "Empty filename"}, 400

    if not allowed_file(file.filename):
        return {"error": f"Invalid file type. Allowed: {', '.join(ALLOWED_EXTENSIONS)}"}, 400

    file.seek(0, os.SEEK_END)
    if file.tell() > MAX_FILE_SIZE:
        return {"error": "File size exceeds limit"}, 413
    file.seek(0)
    return None

def convert_audio_to_wav(input_path: str, output_path: str) -> None:
    """Convert the input audio file to WAV format with OpenAI-friendly specs."""
    ffmpeg_cmd = [
        FFMPEG_PATH, '-y', '-i', input_path,
        '-acodec', 'pcm_s16le', '-ar', '16000', '-ac', '1',
        output_path,
        '-hide_banner', '-loglevel', 'error'
    ]
    subprocess.run(ffmpeg_cmd, stderr=subprocess.PIPE, text=True, check=True)

def split_audio(input_path: str, output_dir: str, chunk_duration_sec: int = 300) -> None:
    """
    Split the WAV file into smaller chunks.
    :param input_path: Path to the WAV file.
    :param output_dir: Directory where chunk files will be saved.
    :param chunk_duration_sec: Duration of each chunk in seconds.
    """
    os.makedirs(output_dir, exist_ok=True)
    base_name = os.path.splitext(os.path.basename(input_path))[0]
    output_pattern = os.path.join(output_dir, f"{base_name}_%03d.wav")
    ffmpeg_cmd = [
        FFMPEG_PATH, '-i', input_path,
        '-f', 'segment',
        '-segment_time', str(chunk_duration_sec),
        '-c', 'copy',
        output_pattern
    ]
    subprocess.run(ffmpeg_cmd, check=True)

def transcribe_chunk(file_path: str) -> str:
    """Transcribe a single audio chunk using the OpenAI API."""
    with open(file_path, 'rb') as audio_file:
        result = client.audio.transcriptions.create(
            model="whisper-1",
            file=audio_file,
            response_format="json"
        )
    return result.text.strip()

def combine_transcripts(transcript_list: List[str]) -> str:
    """Combine a list of transcript strings into a single transcript."""
    return '\n'.join(transcript_list)

def transcribe_large_audio(file_path: str, chunk_duration_sec: int = 300) -> str:
    """
    Split a large audio file into chunks, transcribe each, and combine the transcripts.
    :param file_path: Path to the converted WAV file.
    :param chunk_duration_sec: Duration of each chunk in seconds.
    :return: The complete transcript as a string.
    """
    # Create a temporary directory for the audio chunks
    chunks_dir = file_path + "_chunks"
    split_audio(file_path, chunks_dir, chunk_duration_sec)
    
    transcripts = []
    # Sort chunk files to ensure correct order
    chunk_files = sorted(os.listdir(chunks_dir))
    for fname in chunk_files:
        chunk_path = os.path.join(chunks_dir, fname)
        logging.info(f"Transcribing chunk: {chunk_path}")
        text = transcribe_chunk(chunk_path)
        transcripts.append(text)
    
    full_transcript = combine_transcripts(transcripts)
    
    # Cleanup temporary chunks
    shutil.rmtree(chunks_dir, ignore_errors=True)
    return full_transcript

def cleanup_files(*paths: str) -> None:
    """Attempt to remove the specified file paths."""
    for path in paths:
        try:
            if os.path.exists(path):
                os.remove(path)
        except OSError as e:
            logging.warning(f"Failed to clean up {path}: {e}")

@app.route('/transcribe', methods=['POST'])
@limiter.limit(RATE_LIMIT_TRANSCRIBE)
def transcribe() -> Union[tuple, str]:
    """
    Handle audio file uploads and perform transcription.
    The audio is first converted to WAV, then split into smaller chunks.
    Each chunk is transcribed via the OpenAI API, and the results are combined.
    """
    if 'file' not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files['file']
    validation_error = validate_upload_file(file)
    if validation_error:
        return jsonify(validation_error[0]), validation_error[1]

    filename = secure_filename(file.filename)
    file_path = os.path.join(UPLOAD_FOLDER, filename)
    converted_path = os.path.join(UPLOAD_FOLDER, "converted.wav")

    try:
        if not os.access(UPLOAD_FOLDER, os.W_OK):
            app.logger.error(f"No write permissions in {UPLOAD_FOLDER}")
            return jsonify({"error": "Server cannot write to upload folder"}), 500

        file.save(file_path)

        try:
            convert_audio_to_wav(file_path, converted_path)
        except subprocess.CalledProcessError as e:
            app.logger.error(f"FFmpeg conversion failed: {e.stderr}")
            return jsonify({"error": f"Audio conversion failed: {e.stderr}"}), 400
        except FileNotFoundError:
            app.logger.error(f"FFmpeg not found at {FFMPEG_PATH}")
            return jsonify({"error": "FFmpeg executable not found"}), 500

        # Transcribe the converted audio in chunks
        transcription = transcribe_large_audio(converted_path, chunk_duration_sec=300)

        transcript_id = None
        if transcription:
            with sqlite3.connect(DB_PATH) as conn:
                cursor = conn.execute(
                    "INSERT INTO transcripts (text, filename) VALUES (?, ?)",
                    (transcription, filename)
                )
                transcript_id = cursor.lastrowid
                conn.commit()

        return jsonify({
            "transcription": transcription,
            "transcript_id": transcript_id
        })
    except Exception as e:
        app.logger.error(f"Processing failed: {e}")
        return jsonify({"error": f"Processing error: {e}"}), 500
    finally:
        cleanup_files(converted_path)

@app.route('/transcripts', methods=['GET'])
def get_transcripts() -> str:
    """Fetch all transcripts along with their mini-lecture status."""
    try:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT t.id, t.text, t.timestamp,
                       CASE WHEN MAX(ml.id) IS NOT NULL THEN 1 ELSE 0 END as has_mini_lecture
                FROM transcripts t
                LEFT JOIN mini_lectures ml ON t.id = ml.transcript_id
                GROUP BY t.id, t.text, t.timestamp
                ORDER BY t.timestamp DESC
            """)
            rows = cursor.fetchall()
            transcripts = [{
                "id": row[0],
                "text": row[1],
                "timestamp": row[2],
                "has_mini_lecture": bool(row[3])
            } for row in rows]
        return jsonify(transcripts)
    except Exception as e:
        logging.error(f"Error fetching transcripts: {e}")
        return jsonify({"error": str(e)}), 500

def generate_mini_lecture(transcript_text: str) -> dict:
    """
    Generate a mini-lecture (abstract, key topics, and MCQs) based on the transcript using OpenAI.
    Returns a dictionary with keys: 'abstract', 'key_topics', and 'mcqs'.
    """
    prompt = f"""
Based on the following lecture transcript, generate a mini-lecture with the following structure:

1. Abstract: Write 4–6 sentences summarizing the central themes, key points, and overarching message of the lecture.
2. Key Topics & Explanations: Identify the main topics and significant subtopics from the lecture. For each topic:
   - A one-sentence definition or overview.
   - 1–2 essential insights or critical points emphasized during the lecture.
3. MCQs: Provide 4–5 multiple-choice questions. Each question must include:
   - The question text.
   - Four options (A, B, C, D) as plausible distractors.
   - The correct answer (A/B/C/D).
   - A brief explanation of why the answer is correct.

Return the mini-lecture in valid JSON with the following keys:
{{
  "abstract": "...",
  "key_topics": [
    {{
      "topic": "...",
      "definition": "...",
      "insights": ["...", "..."]
    }},
    ...
  ],
  "mcqs": [
    {{
      "question": "...",
      "options": {{"A": "...", "B": "...", "C": "...", "D": "..."}},
      "correct_answer": "...",
      "explanation": "..."
    }},
    ...
  ]
}}

Lecture Transcript:
{transcript_text}
"""
    try:
        response = client.chat.completions.create(
            model="gpt-4o",  # Use your preferred model
            response_format={"type": "json_object"},
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a helpful educational assistant that creates a mini-lecture based on the transcript. "
                        "Always return a valid JSON object with the keys: 'abstract', 'key_topics', and 'mcqs'."
                    )
                },
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
        )
        content = response.choices[0].message.content
        return json.loads(content)
    except Exception as e:
        logging.error(f"Error generating mini-lecture: {e}")
        raise

@app.route('/generate_mini_lecture/<int:transcript_id>', methods=['POST'])
@limiter.limit(RATE_LIMIT_LECTURE)
def create_mini_lecture(transcript_id: int):
    """
    Generate a mini-lecture for the specified transcript.
    The mini-lecture JSON is stored in the database and returned to the client.
    """
    try:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT text FROM transcripts WHERE id = ?', (transcript_id,))
            result = cursor.fetchone()

            if not result:
                return jsonify({"error": "Transcript not found"}), 404

            transcript_text = result[0]
            lecture_data = generate_mini_lecture(transcript_text)
            cursor.execute(
                'INSERT INTO mini_lectures (transcript_id, lecture_data) VALUES (?, ?)',
                (transcript_id, json.dumps(lecture_data))
            )
            conn.commit()

            return jsonify({
                "message": "Mini-lecture generated successfully",
                "mini_lecture": lecture_data
            })
    except Exception as e:
        logging.error(f"Error in mini-lecture generation endpoint: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500

@app.route('/mini_lecture/<int:transcript_id>', methods=['GET'])
def get_mini_lecture(transcript_id: int):
    """Fetch the mini-lecture for the specified transcript."""
    try:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute(
                'SELECT lecture_data FROM mini_lectures WHERE transcript_id = ? ORDER BY timestamp DESC LIMIT 1',
                (transcript_id,)
            )
            result = cursor.fetchone()
            if result:
                # Convert the stored JSON string back to a JSON object
                lecture_data = json.loads(result[0])
                return jsonify(lecture_data)
            else:
                return jsonify({"error": "Mini-lecture not found"}), 404
    except Exception as e:
        logging.error(f"Error fetching mini-lecture: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/transcript/<int:transcript_id>', methods=['DELETE'])
def delete_transcript(transcript_id: int) -> str:
    """Delete a specific transcript and its associated mini-lecture."""
    try:
        with sqlite3.connect(DB_PATH) as conn:
            conn.execute('DELETE FROM mini_lectures WHERE transcript_id = ?', (transcript_id,))
            conn.execute('DELETE FROM transcripts WHERE id = ?', (transcript_id,))
            conn.commit()
        return jsonify({"message": "Transcript deleted successfully"})
    except Exception as e:
        logging.error(f"Error deleting transcript: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/transcripts', methods=['DELETE'])
def delete_all_transcripts() -> str:
    """Delete all transcripts and mini-lectures."""
    try:
        with sqlite3.connect(DB_PATH) as conn:
            conn.execute('DELETE FROM mini_lectures')
            conn.execute('DELETE FROM transcripts')
            conn.commit()
        return jsonify({"message": "All transcripts deleted successfully"})
    except Exception as e:
        logging.error(f"Error deleting all transcripts: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    if not os.access(UPLOAD_FOLDER, os.W_OK):
        print(f"ERROR: No write permissions in {UPLOAD_FOLDER}")
        exit(1)
    
    debug_mode = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    app.run(host=SERVER_HOST, port=SERVER_PORT, debug=debug_mode)
