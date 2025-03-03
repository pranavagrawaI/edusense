import os
import whisper
from flask import Flask, request, jsonify
from flask_limiter import Limiter
from werkzeug.utils import secure_filename

app = Flask(__name__)
limiter = Limiter(app)

# Load the Whisper Tiny model once at startup
model = whisper.load_model("tiny")

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

ALLOWED_EXTENSIONS = {'wav', 'mp3', 'ogg', 'flac'}
MAX_FILE_SIZE = 16 * 1024 * 1024  # 16MB

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/transcribe', methods=['POST'])
@limiter.limit("10/minute")  # Adjust the limit as needed
def transcribe():
    if 'file' not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "Empty filename"}), 400

    if not allowed_file(file.filename):
        return jsonify({"error": "Invalid file type"}), 400

    if len(file.read()) > MAX_FILE_SIZE:
        return jsonify({"error": "File size exceeds the limit"}), 413

    file.seek(0)  # Reset the file pointer

    # Save the file
    filename = secure_filename(file.filename)
    file_path = os.path.join(UPLOAD_FOLDER, filename)
    file.save(file_path)

    # Transcribe audio
    try:
        result = model.transcribe(file_path)
        transcription = result.get("text", "")
    except Exception as e:
        # Return error if Whisper fails
        return jsonify({"error": str(e)}), 500
    finally:
        # Cleanup: remove the uploaded file to save space
        if os.path.exists(file_path):
            os.remove(file_path)

    return jsonify({"transcription": transcription})

if __name__ == '__main__':
    # Run on 0.0.0.0 so it's accessible on your local network
    app.run(host='0.0.0.0', port=5000, debug=True)