# EduSense

EduSense is a real-time AI+IoT platform that augments live classroom teaching by autonomously generating structured educational content—summaries, key concepts, and quizzes—from lecture audio. Designed for minimal classroom disruption and maximum learning impact, EduSense brings intelligence and adaptability to traditional education.

## 🎯 Objectives

EduSense aims to:

- Enhance student comprehension and retention through real-time content generation.
- Support teachers with automated feedback and pedagogical insights.
- Operate as a lightweight, deployable system that integrates seamlessly with classroom routines.

## 🔧 System Overview

The system consists of:

- **Audio Capture**: Records lectures using built-in or external microphones.
- **Speech Recognition**: Uses Whisper ASR for high-fidelity transcription (WER: 2.8–5.0%).
- **Natural Language Processing**: Applies GPT-based models to extract key concepts and generate mini-lectures with dynamic summaries and MCQs.
- **Mobile App Interface**: Displays content to students and logs feedback.
- **Offline Syncing**: Operates in low-connectivity environments and syncs when online.

## 📊 Evaluation Highlights

- **Semantic Fidelity**: BERTScore F1 > 0.94 across summaries and quizzes.
- **User Ratings**: Students rated EduSense >4.2/5 on comprehension, usability, and usefulness.
- **Reliability**: Smooth deployment across five IoT-focused lectures with 17 undergraduates.

## 🔬 Research Contribution

EduSense demonstrates that lightweight, real-time AI integration into live classrooms is both technically feasible and pedagogically impactful, bridging a key research gap in educational AI. It combines objective metrics (WER, BERTScore) with subjective evaluations (Likert-scale surveys) to assess its effectiveness.

## 🛠 Future Directions

- Longitudinal studies on academic retention and performance.
- Expansion across disciplines, languages, and class sizes.
- On-device inference for lower latency and improved privacy.
- Richer content via multimodal inputs (slides, textbooks, video).

## 📚 Citation

Agrawal, P. (2025). *EduSense: Evaluating AI for Augmenting Live Classroom Teaching*. IISER Bhopal.
