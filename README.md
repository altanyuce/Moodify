# Moodify

Moodify is an AI-powered mobile application that transforms visual context into music recommendations.

It analyzes images in real time and generates context-aware song suggestions using a hybrid pipeline combining vision AI, rule-based scoring, and external music discovery.

> Built to explore AI-driven recommendation systems and resilient mobile application design.

---

## Overview

Moodify takes a user-selected image and processes it through a vision model to extract semantic information such as mood, environment, and objects. This analysis is then used to generate music recommendations through a hybrid pipeline:

- AI-based visual analysis (Gemini)
- Rule-based scoring and filtering
- External music discovery (Deezer API)
- Local fallback catalog

The goal is to move beyond static playlists and provide dynamic, context-driven music suggestions.

---

## Features

- Image-based mood detection using a vision AI model
- Hybrid recommendation system (AI + scoring + external API)
- Integration with Deezer for dynamic music discovery
- Fallback system for API failures and edge cases
- Retry mechanism for incomplete or invalid AI responses
- Recommendation diversity via candidate scoring and randomization
- "Try another suggestion" functionality with reduced repetition
- Cross-platform mobile development with Flutter
- Resilient recommendation pipeline with retry and fallback mechanisms

---

## Architecture

### 1. Vision Layer
- Sends selected image to Gemini API
- Extracts:
  - Mood
  - Scene
  - Objects
- Handles:
  - API errors (429, 503)
  - Incomplete responses
  - Retry logic
  - Fallback analysis

### 2. Recommendation Layer
- Scores songs based on:
  - Mood match
  - Scene relevance
  - Object similarity
- Applies:
  - Recent song filtering
  - Artist diversity control
  - Candidate ranking
  - Randomized selection

### 3. Discovery Layer
- Generates search queries from AI output
- Fetches tracks from Deezer API
- Deduplicates results
- Falls back to local catalog if needed

---

## Reliability Strategy

The application is designed to remain functional even when AI or external APIs fail.

- AI responses are validated and parsed into structured data
- Incomplete or invalid responses trigger a retry mechanism
- API failures (e.g. 429, 503) are handled gracefully
- A local fallback system ensures a result is always produced
- Recommendation logic continues even with low-confidence AI outputs

This approach ensures a resilient user experience under unstable network or API conditions.

---

## Tech Stack

- **Flutter** (Mobile Development)
- **Dart**
- **Gemini Vision API** (Image Analysis)
- **Deezer API** (Music Discovery)
- **REST API Integration**
- **Asynchronous Data Handling & Error Recovery**

---

## Project Structure

```bash
lib/
  models/
  services/
    vision_service.dart
    recommendation_service.dart
    music_discovery_service.dart
  screens/
    home_screen.dart
    loading_screen.dart
    result_screen.dart
  data/
    song_catalog.dart
```

---

## Getting Started

### Prerequisites

- Flutter SDK
- Android Studio or VS Code
- Physical device or emulator

### Installation

```bash
git clone https://github.com/altanyuce/moodify.git
cd moodify
flutter pub get
```

### Configuration

The application uses runtime configuration for API keys:

GEMINI_API_KEY → required for vision analysis

No API keys are stored in the repository.

## Known Limitations

- Vision API may occasionally return incomplete responses
- Some image formats (e.g. HEIC) may not be fully supported on all devices
- Music recommendations depend on query quality from AI output
- External API availability may affect results

## Future Improvements

- Improved semantic mapping for music queries
- Additional music providers (e.g. Spotify, Last.fm)
- Better handling of unsupported image formats
- Offline recommendation enhancements
- User personalization and history tracking

