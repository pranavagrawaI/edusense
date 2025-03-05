import os
import whisper
from flask import Flask, request, jsonify, abort
from flask_limiter import Limiter
from werkzeug.utils import secure_filename
import subprocess
from typing import Tuple, Dict
import wave
import sqlite3
import logging

app = Flask(__name__)
limiter = Limiter(app)

# Constants
UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")
ALLOWED_EXTENSIONS = {'wav', 'mp3', 'ogg', 'flac', 'aac'}
MAX_FILE_SIZE = 16 * 1024 * 1024  # 16MB
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "transcripts.db")
FFMPEG_PATH = 'ffmpeg'  # Or set a specific path if needed

# Initialize once at startup
model = whisper.load_model("tiny")

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Configure logging
logging.basicConfig(level=logging.ERROR)  # Or a different level if you prefer

def init_db():
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute('''CREATE TABLE IF NOT EXISTS transcripts
                     (id INTEGER PRIMARY KEY AUTOINCREMENT,
                      text TEXT NOT NULL,
                      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                      filename TEXT)''')

init_db()

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
@limiter.limit("10/minute")
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
        if transcription:
            with sqlite3.connect(DB_PATH) as conn:
                conn.execute("INSERT INTO transcripts (text, filename) VALUES (?, ?)",
                           (transcription, filename))

        return jsonify({"transcription": transcription})

    except Exception as e:
        app.logger.error(f"Processing failed: {str(e)}")
        #  Rollback database transaction if necessary (using a connection pool)
        return jsonify({"error": f"Processing error: {str(e)}"}), 500

    finally:
        # Clean up files
        for path in [file_path, converted_path]:
            try:
                if os.path.exists(path): # Redundant check removed
                    os.remove(path)
            except OSError as e:
                app.logger.warning(f"Failed to clean up {path}: {str(e)}")

@app.route('/transcripts', methods=['GET'])
def get_transcripts():
    try:
        with sqlite3.connect(DB_PATH) as conn:
            cur = conn.cursor()
            cur.execute("SELECT id, text, timestamp, filename FROM transcripts ORDER BY timestamp DESC")
            rows = cur.fetchall()
            
        return jsonify([{
            "id": row[0],
            "text": row[1],
            "timestamp": row[2],
            "filename": row[3]
        } for row in rows])
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    if not os.access(UPLOAD_FOLDER, os.W_OK):
        print(f"ERROR: No write permissions in {UPLOAD_FOLDER}")
        exit(1)
    
    app.run(host='0.0.0.0', port=5000, debug=True)