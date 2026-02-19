# AI SOS Guardian

## 🚨 Project Overview

AI SOS Guardian is a mobile-first safety application that empowers users to trigger SOS alerts via a button or custom voice safe word. The app securely transmits live location, audio/video, and messages to trusted contacts. Future versions integrate AI for real-time distress detection and encryption for tamper-proof communication.

---

## 🎯 Problem Statement

Traditional SOS apps are limited — they only send static SMS/location and often fail in real emergencies where the user can’t interact with the phone. Rising safety concerns (especially women’s safety, road accidents, and outdoor activities like hiking) demand smarter, proactive solutions.

---

## 🌟 MVP Goal

**“Tap button → Send live location + SOS message to a trusted contact.”**

This establishes the foundation for AI-driven upgrades later.

---

## 🛠 Tech Stack

* **Mobile App:** Flutter (cross-platform, Android-first)
* **Backend API:** FastAPI (Python)
* **Database:** PostgreSQL
* **AI/NLP (Phase 2):** Whisper/Vosk for speech-to-text → custom safe word detection
* **Notification Services:** Twilio (SMS), Firebase (push notifications)

---

## 📂 Project Structure

```
ai-sos-guardian/
├── mobile/        # Flutter app code
├── backend/       # FastAPI backend
├── ai-models/     # Speech/NLP models (later phase)
├── docs/          # Documentation, diagrams
├── tests/         # Unit and integration tests
└── README.md
```

---

## 🔑 Core Features (Phases)

### Phase 1 (MVP)

* User registration
* Add trusted contacts (name + phone/email)
* SOS button → backend API → sends alert with live location

### Phase 2

* AI speech recognition with **custom safe word** (user-defined passphrase)
* Background monitoring (continuous listening with consent)

### Phase 3

* Encrypted live audio/video streaming to contacts
* Panic mode (stealth activation, phone looks idle but transmits data)

---

## 🖼 Architecture Diagram (Textual)

```
[Mobile App]
  |-- SOS Button Press
  |-- Voice Safe Word Detected (AI)
        ↓
[FastAPI Backend]
  |-- Store SOS Event in DB
  |-- Trigger Notification (SMS/Push)
        ↓
[Trusted Contact Device]
  |-- Receives location + alert
  |-- (Future) Access secure live stream
```

---

## 🚀 Roadmap

1. Create repo + skeleton folders
2. Implement MVP (button-based SOS → notification)
3. Add safe word feature (speech-to-text AI)
4. Add encryption + audio/video streaming
5. Optimize performance + polish UI

---

## 🤝 Contributors

* Cybersecurity Team → Secure communication, backend, encryption
* AI Team → Speech-to-text models, safe word detection
* Mobile Dev → Flutter frontend, UX

---

## 📌 Why This Project Matters

* Real-world safety impact (India context: women’s safety, road accidents)
* Mixes **AI + Cybersecurity + Mobile-first development**
* Practical, scalable, and resume-worthy
