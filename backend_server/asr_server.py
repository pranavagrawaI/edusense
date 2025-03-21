import os
import json
import sqlite3
import logging
import subprocess
from datetime import datetime
from typing import Tuple, Dict, Optional, Union
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

# Load the and initialize the OpenAI client
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
    """Convert the input audio file to WAV format using FFmpeg."""
    ffmpeg_cmd = [
        FFMPEG_PATH, '-y', '-i', input_path,
        '-acodec', 'pcm_s16le', '-ar', '16000', '-ac', '1',
        output_path,
        '-hide_banner', '-loglevel', 'error'
    ]
    subprocess.run(
        ffmpeg_cmd,
        stderr=subprocess.PIPE,
        text=True,
        check=True
    )

def cleanup_files(*paths: str) -> None:
    """Attempt to remove provided file paths."""
    for path in paths:
        try:
            if os.path.exists(path):
                os.remove(path)
        except OSError as e:
            logging.warning(f"Failed to clean up {path}: {e}")

@app.route('/transcribe', methods=['POST'])
@limiter.limit(RATE_LIMIT_TRANSCRIBE)
def transcribe() -> Union[tuple, str]:
    """Handle audio file upload and transcription."""
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

        abs_converted_path = os.path.abspath(converted_path)
        
        with open(abs_converted_path, 'rb') as audio_file:
            result = client.audio.transcriptions.create(
            model="whisper-1",
            file=audio_file,
            response_format="json"
            )

        transcription = result.text.strip()

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
        cleanup_files(file_path, converted_path)

@app.route('/transcripts', methods=['GET'])
def get_transcripts() -> str:
    """Fetch all transcripts along with their lecture status."""
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
    Generate a mini-lecture (abstract, key topics, and MCQs) from a transcript using OpenAI.
    Returns a dictionary with keys: 'abstract', 'key_topics', and 'mcqs'.
    """
    prompt = f"""
Based on the following lecture transcript, generate a mini-lecture with the following structure:

1. Abstract: Write 4–6 sentences summarizing the central themes, key points, and overarching message of the lecture.
2. Key Topics & Explanations: Identify the main topics and significant subtopics from the lecture. For each topic:
   - A one-sentence definition or overview.
   - 1–2 essential insights or critical points emphasized during the lecture.
3. MCQs: Provide 2–3 multiple-choice questions. Each question must include:
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
            model="gpt-4o",
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

        # Attempt to parse the content as JSON
        return json.loads(content)
    except Exception as e:
        logging.error(f"Error generating mini-lecture: {e}")
        raise


@app.route('/generate_mini_lecture/<int:transcript_id>', methods=['POST'])
@limiter.limit(RATE_LIMIT_LECTURE)
def create_mini_lecture(transcript_id: int):
    """
    Generate a mini-lecture for the specified transcript.
    Stores the mini-lecture JSON in the mini_lectures table
    and returns the generated data to the client.
    """
    try:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            # Fetch the transcript text
            cursor.execute('SELECT text FROM transcripts WHERE id = ?', (transcript_id,))
            result = cursor.fetchone()

            if not result:
                return jsonify({"error": "Transcript not found"}), 404

            transcript_text = result[0]
            
            # Generate the mini-lecture
            lecture_data = generate_mini_lecture(transcript_text)
            
            # Store it in the mini_lectures table as JSON
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