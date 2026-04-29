# BlindNav - Independent Navigation for the Visually Impaired

BlindNav is an intelligent, voice-first companion app designed to help visually impaired individuals navigate unfamiliar environments safely and independently. 

Built for the **Google Solutions Challenge**, this project directly addresses **UN Sustainable Development Goal 11: Sustainable Cities and Communities** by making public spaces more accessible and safer for everyone.

## 🚀 Live Prototype & Demo
* **Live Web App:** [Insert your Firebase Web URL here, e.g., https://blindnav-34260.web.app]
* **Video Demo:** [Insert your YouTube video link here]

## 🛠️ Built With (Google Technologies)
* **Flutter:** For a cross-platform, highly responsive user interface.
* **Firebase Auth:** For seamless and secure anonymous user sign-in.
* **Firebase Hosting:** For fast, secure deployment of our web prototype.
* **Google Maps Platform:** 
  * **Places API:** To identify and announce nearby landmarks.
  * **Directions API:** To generate safe, step-by-step walking routes.
* **Speech-to-Text & Text-to-Speech:** Enabling a completely hands-free, accessible user experience.

## 📱 Key Features
1. **Voice-Activated Navigation:** Users can simply ask to go to a location, and the app calculates the route.
2. **Spatial Awareness:** The app reads out nearby landmarks and points of interest to help users understand their surroundings.
3. **Conversational Directions:** Step-by-step walking directions are spoken aloud naturally.
4. **Safety Scan (Mocked for Demo):** Designed to integrate with device cameras to identify immediate physical hazards in the user's path.

## 💻 How to Run Locally
1. Clone the repository: `git clone <your-repo-url>`
2. Navigate to the project directory: `cd blind_nav`
3. Install dependencies: `flutter pub get`
4. *Note: You will need to provide your own Google Maps API Key in `lib/services/maps_service.dart` and `android/app/src/main/AndroidManifest.xml` to build locally.*
5. Run the app: `flutter run`
