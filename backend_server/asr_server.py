import os
import whisper
from flask import Flask, request, jsonify, abort
from flask_limiter import Limiter
from werkzeug.utils import secure_filename
import subprocess
from typing import Tuple, Dict
import sqlite3
import logging
from openai import OpenAI
from datetime import datetime
from dotenv import load_dotenv  # Add this import
import json

# Load environment variables
load_dotenv()

# Constants from environment variables
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
FLASK_SECRET_KEY = os.getenv('FLASK_SECRET_KEY')
SERVER_HOST = os.getenv('SERVER_HOST', '0.0.0.0')
SERVER_PORT = int(os.getenv('SERVER_PORT', '5000'))
MAX_FILE_SIZE = int(os.getenv('MAX_FILE_SIZE', '16777216'))
UPLOAD_FOLDER = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), 
    os.getenv('UPLOAD_FOLDER', 'uploads')
)
DB_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), 
    os.getenv('DB_PATH', 'transcripts.db')
)
FFMPEG_PATH = os.getenv('FFMPEG_PATH', 'ffmpeg')
RATE_LIMIT_TRANSCRIBE = os.getenv('RATE_LIMIT_TRANSCRIBE', '10/minute')
RATE_LIMIT_QUIZ = os.getenv('RATE_LIMIT_QUIZ', '5/minute')

# Validate required environment variables
required_vars = ['OPENAI_API_KEY', 'FLASK_SECRET_KEY']
missing_vars = [var for var in required_vars if not os.getenv(var)]
if missing_vars:
    raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")

# Configure Flask app
app = Flask(__name__)
app.secret_key = FLASK_SECRET_KEY
limiter = Limiter(app)

# Constants
ALLOWED_EXTENSIONS = {'wav', 'mp3', 'ogg', 'flac', 'aac'}
FFMPEG_PATH = 'ffmpeg'  # Or set a specific path if needed

# Initialize once at startup
model = whisper.load_model("tiny")

# Initialize OpenAI client (after loading environment variables)
client = OpenAI(api_key=OPENAI_API_KEY)

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Configure logging to file
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("asr_server.log"),
        logging.StreamHandler()  # Also log to console
    ]
)

def init_db():
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute('''CREATE TABLE IF NOT EXISTS transcripts
                     (id INTEGER PRIMARY KEY AUTOINCREMENT,
                      text TEXT NOT NULL,
                      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                      filename TEXT)''')

def init_quiz_db():
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute('''CREATE TABLE IF NOT EXISTS quizzes
                     (id INTEGER PRIMARY KEY AUTOINCREMENT,
                      transcript_id INTEGER,
                      quiz_data TEXT NOT NULL,
                      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                      FOREIGN KEY (transcript_id) REFERENCES transcripts(id))''')

init_db()
init_quiz_db()

def allowed_file(filename: str) -> bool:
    """Check if file extension is allowed."""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def validate_upload_file(file) -> Tuple[Dict, int] | None:
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

@app.route('/transcribe', methods=['POST'])
@limiter.limit(RATE_LIMIT_TRANSCRIBE)
def transcribe():
    """Handle audio file upload and transcription."""
    if 'file' not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files['file']
    if (validation := validate_upload_file(file)):
        return jsonify(validation[0]), validation[1]

    filename = secure_filename(file.filename)
    file_path = os.path.join(UPLOAD_FOLDER, filename)
    converted_path = os.path.join(UPLOAD_FOLDER, "converted.wav")
    transcription = None

    try:
        # Check readability *before* saving
        if not os.access(UPLOAD_FOLDER, os.W_OK):
            app.logger.error(f"No write permissions in {UPLOAD_FOLDER}")
            return jsonify({"error": "Server cannot write to upload folder"}), 500

        file.save(file_path)

        # Convert to WAV using FFmpeg if needed
        try:
            ffmpeg_cmd = [
                FFMPEG_PATH, '-y', '-i', file_path,
                '-acodec', 'pcm_s16le', '-ar', '16000', '-ac', '1',
                converted_path,
                '-hide_banner', '-loglevel', 'error'
            ]
            result = subprocess.run(
                ffmpeg_cmd,
                stderr=subprocess.PIPE,
                text=True,
                check=True  # Raise CalledProcessError for non-zero exit codes
            )

        except subprocess.CalledProcessError as e:
            app.logger.error(f"FFmpeg conversion failed: {e.stderr}")
            return jsonify({"error": f"Audio conversion failed: {e.stderr}"}), 400
        except FileNotFoundError:
            app.logger.error(f"FFmpeg not found at {FFMPEG_PATH}")
            return jsonify({"error": "FFmpeg executable not found"}), 500

        # Process transcription from converted file
        abs_path = os.path.abspath(converted_path)
        result = model.transcribe(
            abs_path,
            language='en',  # Force English detection
            fp16=False  # Better compatibility
        )
        transcription = result.get("text", "").strip()

        # Store in database *before* cleanup
        transcript_id = None
        if transcription:
            with sqlite3.connect(DB_PATH) as conn:
                cursor = conn.execute("INSERT INTO transcripts (text, filename) VALUES (?, ?)",
                           (transcription, filename))
                transcript_id = cursor.lastrowid
                conn.commit()
        
        return jsonify({
            "transcription": transcription,
            "transcript_id": transcript_id
        })

    except Exception as e:
        app.logger.error(f"Processing failed: {str(e)}")
        return jsonify({"error": f"Processing error: {str(e)}"}), 500

    finally:
        # Clean up files
        for path in [file_path, converted_path]:
            try:
                if os.path.exists(path): 
                    os.remove(path)
            except OSError as e:
                app.logger.warning(f"Failed to clean up {path}: {str(e)}")

@app.route('/transcripts', methods=['GET'])
def get_transcripts():
    """Fetch all transcripts with their IDs."""
    try:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT t.id, t.text, t.timestamp, 
                       CASE WHEN q.id IS NOT NULL THEN 1 ELSE 0 END as has_quiz
                FROM transcripts t
                LEFT JOIN quizzes q ON t.id = q.transcript_id
                ORDER BY t.timestamp DESC
            """)
            rows = cursor.fetchall()
            
            return jsonify([{
                "id": row[0],
                "text": row[1],
                "timestamp": row[2],
                "has_quiz": bool(row[3])
            } for row in rows])
    except Exception as e:
        logging.error(f"Error fetching transcripts: {str(e)}")
        return jsonify({"error": str(e)}), 500

def generate_quiz(transcript_text: str, num_questions: int = 5) -> dict:
    """Generate quiz questions from transcript using OpenAI."""
    try:
        prompt = f"""
        Based on the following lecture transcript, generate {num_questions} quiz questions.
        For each question, provide:
        1. The question
        2. Four multiple choice options (A, B, C, D)
        3. The correct answer
        4. A brief explanation of why it's correct

        Transcript:
        {transcript_text}
        """

        response = client.chat.completions.create(
            model="gpt-4o-mini",  
            response_format={"type": "json_object"},  
            messages=[
                {
                    "role": "system",
                    "content": "You are a helpful educational assistant that creates quiz questions based on lecture content. Always return response in the following JSON format: {'questions': [{'question': '...', 'options': {'A': '...', 'B': '...', 'C': '...', 'D': '...'}, 'correct_answer': 'A/B/C/D', 'explanation': '...'}]}"
                },
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            seed=42  # Optional: Add for more deterministic outputs
        )

        # Get the content as a string (it should already be valid JSON)
        content = response.choices[0].message.content
        
        # Log the response for debugging
        logging.info(f"API response content type: {type(content)}")
        logging.info(f"API response content: {content}")
        
        # For OpenAI API, content should be a string containing valid JSON
        # Parse it into a Python dictionary
        try:
            return json.loads(content)
        except (json.JSONDecodeError, TypeError) as e:
            # If JSON parsing fails, return the content directly if it's already a dict
            if isinstance(content, dict):
                return content
            # Otherwise, raise the error
            logging.error(f"Failed to parse JSON: {e}")
            raise ValueError(f"Invalid JSON response from API: {e}")

    except Exception as e:
        logging.error(f"Error generating quiz: {str(e)}")
        raise

@app.route('/generate_quiz/<int:transcript_id>', methods=['POST'])
@limiter.limit(RATE_LIMIT_QUIZ)
def create_quiz(transcript_id):
    try:
        with sqlite3.connect(DB_PATH) as conn:
            # Get transcript text
            cursor = conn.cursor()
            cursor.execute('SELECT text FROM transcripts WHERE id = ?', (transcript_id,))
            result = cursor.fetchone()
            
            if not result:
                return jsonify({"error": "Transcript not found"}), 404
                
            transcript_text = result[0]
            
            # Generate quiz
            quiz_data = generate_quiz(transcript_text)
            
            # Store quiz in database
            cursor.execute(
                'INSERT INTO quizzes (transcript_id, quiz_data) VALUES (?, ?)',
                (transcript_id, json.dumps(quiz_data))
            )
            conn.commit()
            
            return jsonify({
                "message": "Quiz generated successfully",
                "quiz_data": quiz_data
            })
            
    except Exception as e:
        logging.error(f"Error in quiz generation endpoint: {str(e)}", exc_info=True)
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    if not os.access(UPLOAD_FOLDER, os.W_OK):
        print(f"ERROR: No write permissions in {UPLOAD_FOLDER}")
        exit(1)
    
    debug_mode = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    app.run(
        host=SERVER_HOST, 
        port=SERVER_PORT, 
        debug=debug_mode
    )