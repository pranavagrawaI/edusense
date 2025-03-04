import os
import whisper
from flask import Flask, request, jsonify
from flask_limiter import Limiter
from werkzeug.utils import secure_filename
import subprocess
from typing import Tuple, Dict
import wave

app = Flask(__name__)
limiter = Limiter(app)

# Constants
UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")
ALLOWED_EXTENSIONS = {'wav', 'mp3', 'ogg', 'flac', 'aac'}
MAX_FILE_SIZE = 16 * 1024 * 1024  # 16MB

# Initialize once at startup
model = whisper.load_model("tiny")
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

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

    try:
        # Save and validate file
        filename = secure_filename(file.filename)
        file_path = os.path.join(UPLOAD_FOLDER, filename)
        file.save(file_path)
        
        if not os.path.exists(file_path):
            app.logger.error(f"File not found: {file_path}")
            return jsonify({"error": "File upload failed"}), 500

        if not os.access(file_path, os.R_OK):
            app.logger.error("File not readable after saving")

        # Convert to WAV using FFmpeg if needed
        converted_path = os.path.join(UPLOAD_FOLDER, "converted.wav")
        try:
            ffmpeg_cmd = [
                'ffmpeg', '-y', '-i', file_path,
                '-acodec', 'pcm_s16le', '-ar', '16000', '-ac', '1',
                converted_path,
                '-hide_banner', '-loglevel', 'error'
            ]
            result = subprocess.run(
                ffmpeg_cmd,
                stderr=subprocess.PIPE,
                text=True
            )
            if result.returncode != 0:
                raise ValueError(f"FFmpeg conversion failed: {result.stderr}")
        except Exception as e:
            return jsonify({"error": str(e)}), 400

        # Process transcription from converted file
        abs_path = os.path.abspath(converted_path)
        result = model.transcribe(
            abs_path,
            language='en',  # Force English detection
            fp16=False  # Better compatibility
        )
        transcription = result.get("text", "").strip()

        return jsonify({"transcription": transcription})
        
    except Exception as e:
        app.logger.error(f"Processing failed: {str(e)}")
        return jsonify({"error": f"Processing error: {str(e)}"}), 500
    finally:
        # Clean up both files
        for path in [file_path, converted_path]:
            if path and os.path.exists(path):
                try:
                    os.remove(path)
                except Exception as e:
                    app.logger.warning(f"Failed to clean up {path}: {str(e)}")

if __name__ == '__main__':
    if not os.access(UPLOAD_FOLDER, os.W_OK):
        print(f"ERROR: No write permissions in {UPLOAD_FOLDER}")
        exit(1)
    
    app.run(host='0.0.0.0', port=5000, debug=True)