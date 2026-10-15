# Pirate LLM Server

Turn your iPhone into a local LLM server with an OpenAI-compatible API. Run GGUF models on-device with Metal GPU acceleration and serve them across your local network.

No cloud. No subscriptions. No jailbreak. Just your iPhone and a model.

<p align="center">
  <img src="image/IMG_8095.PNG" width="230" alt="Home Screen">
  <img src="image/IMG_8096.PNG" width="230" alt="Model Loaded">
  <img src="image/IMG_8097.PNG" width="230" alt="Server Running">
</p>

<p align="center">
  <img src="image/terminal.png" width="700" alt="Terminal streaming response">
</p>

## Highlights

- **OpenAI-Compatible API**: Drop-in replacement for OpenAI endpoints (`POST /v1/chat/completions`, `GET /v1/models`, `GET /`). Works out-of-the-box with Open WebUI, NextChat, Chatbox, SillyTavern, and custom scripts.
- **Streaming & Non-Streaming**: Full Server-Sent Events (SSE) streaming support (`stream: true`) as well as single-payload JSON completions.
- **Metal GPU Acceleration**: Powered by llama.cpp compiled natively for Apple Silicon iOS with Metal acceleration.
- **Windows-Friendly CI/CD**: Build unsigned IPAs automatically via GitHub Actions with zero macOS hardware requirements, then sideload via Sideloadly or AltStore.
- **Low-Memory Optimization**: Curated presets and tuning guidance for 3GB RAM devices like iPhone SE (2nd Gen) up to flagship 8GB+ devices.
- **Model Presets & Downloader**: One-tap downloads for popular small and medium models, custom HuggingFace direct URL downloader, and high-speed USB file sharing.
- **Persistent Server Operation**: Built-in silent background audio keep-alive and screen wake lock to keep the server alive on your local network.
- **CORS Enabled**: Cross-origin requests allowed by default (`*`) for web-based frontends running anywhere on your LAN.

---

## Device & System Compatibility

| Device Class | Typical RAM | Available App RAM (Jetsam Limit) | Recommended Models |
|---|---|---|---|
| **Low-Memory**<br>(iPhone SE 2nd Gen, iPhone 8 Plus, iPhone XR / 11) | 3 GB | ~1.3 GB – 1.8 GB | **Qwen 2.5 0.5B Instruct** (Q4_K_M)<br>**Llama 3.2 1B Instruct** (Q4_K_M) |
| **Mid-Memory**<br>(iPhone 12 / 13 / 14 / 15, iPad 9th/10th) | 4 GB – 6 GB | ~2.5 GB – 4.0 GB | **Qwen 2.5 1.5B Instruct** (Q4_K_M)<br>**Qwen 3.5 2B** (Q4_K_M) |
| **High-Memory**<br>(iPhone 15 Pro, iPhone 16 / 16 Pro, iPad Pro M-series) | 8 GB+ | ~5.0 GB – 7.0 GB | **Qwen 2.5 3B / 7B** (Q4_K_M)<br>**Llama 3.1 8B** (Q4_K_M / IQ4_XS) |

> **Note on iOS Memory Limits (Jetsam)**: iOS imposes per-process memory limits. On a 3GB device such as the iPhone SE (2nd Gen) running iOS 17, exceeding approximately 1.5 GB memory will cause the operating system to terminate the app (`EXC_RESOURCE / JETSAM`). For 3GB devices, use **Qwen 2.5 0.5B** or **Llama 3.2 1B**.

---

## Installation & Sideloading

You can deploy Pirate LLM Server either by downloading precompiled IPAs from GitHub Actions (ideal for Windows and Linux users) or by building locally from source with Xcode on macOS.

### Method 1: Windows / Automated Build via GitHub Actions & Sideloadly (Recommended)

No Mac or local Xcode installation is required.

#### 1. Generate or Download the IPA
1. Push or fork this repository to GitHub.
2. In your repository, click the **Actions** tab.
3. Select the **Build Unsigned IPA** workflow and click **Run workflow** (or push a commit to `main`).
4. Once completed, download the artifact named **`LLMServer-unsigned-ipa`** and extract `LLMServer.ipa`.

#### 2. Sideload via Sideloadly
1. Download and install [Sideloadly](https://sideloadly.io) on Windows or macOS.
2. Ensure you have the standard Apple mobile drivers installed (on Windows, install standalone [iTunes 64-bit](https://www.apple.com/itunes/) and iCloud; avoid Microsoft Store editions).
3. Connect your iPhone to your computer with a USB cable and tap **Trust this computer** on the phone screen.
4. Launch Sideloadly:
   - Verify your iPhone appears in the **Connected Device** dropdown.
   - Drag and drop `LLMServer.ipa` onto the IPA box in Sideloadly.
   - Enter your Apple ID email.
   - Click **Start** and provide your Apple ID password / 2FA code when prompted.
5. Wait for Sideloadly to sign and install the app onto your iPhone.

#### 3. iOS Trust & Developer Mode Setup
- **Trust Certificate**: On your iPhone, navigate to **Settings** → **General** → **VPN & Device Management** → select your Apple ID under *Developer App* → tap **Trust**.
- **Enable Developer Mode (iOS 16 & iOS 17)**:
  1. Open **Settings** → **Privacy & Security**.
  2. Scroll to the bottom and select **Developer Mode**.
  3. Toggle Developer Mode **ON** and tap **Restart**.
  4. After restarting, unlock the phone and tap **Turn On** on the confirmation prompt.

---

### Method 2: macOS Local Build with Xcode

#### Prerequisites
- macOS 14+ with Xcode 15+
- Command Line Tools installed (`xcode-select --install`)
- CMake (`brew install cmake`)
- Git

#### Build & Run
```bash
# 1. Clone the repository
git clone https://github.com/pinperepette/PirateLLMServer.git
cd PirateLLMServer

# 2. Build llama.cpp as an XCFramework for iOS
./setup.sh

# 3. Open project in Xcode
open LLMServer.xcodeproj
```

- In Xcode, select the `LLMServer` target.
- Under **Signing & Capabilities**, select your personal or team Apple Developer account.
- Connect your iPhone, select it as the target device, and press **Cmd + R** to compile and run.

#### `setup.sh` Command Options
The `setup.sh` script supports additional flags:
```bash
./setup.sh [OPTIONS]

Options:
  --clean        Remove existing build directories and rebuild llama.xcframework from scratch
  --copy         Copy xcframework into local Swift package rather than symlinking
  --skip-build   Reuse existing build-apple/llama.xcframework if already present
  --help         Show usage help
```

---

## Loading Models

Pirate LLM Server supports any GGUF format model compatible with llama.cpp.

### In-App Presets & Downloader
Inside the app's **Download Model** section:
- **Preset Buttons**:
  - `Qwen 2.5 0.5B Instruct` (Q4_K_M, ~398 MB) — Ultra-low RAM usage (~650 MB), ideal for iPhone SE2 / 3GB RAM.
  - `Llama 3.2 1B Instruct` (Q4_K_M, ~800 MB) — Recommended for 3GB RAM with good balance of reasoning and speed.
  - `Qwen 2.5 1.5B Instruct` (Q4_K_M, ~986 MB) — Capable 1.5B model, works on 3GB RAM with smaller context sizes.
  - `Qwen 3.5 2B` (Q4_K_M, ~1.5 GB) — Best for 4GB+ RAM devices.
- **Custom URL**: Paste any direct `.gguf` download link (e.g. from HuggingFace `resolve/main/...`) into the URL field and tap **Download**.

### High-Speed USB Transfer
For large models, USB transfer is significantly faster than Wi-Fi downloads:

- **On Windows**:
  1. Open **Apple Devices** app or **iTunes** (or 3uTools).
  2. Select your connected iPhone.
  3. Go to **File Sharing** → select **LLMServer**.
  4. Drag and drop your `.gguf` file into the documents area.
- **On macOS**:
  1. Open **Finder** and select your iPhone in the sidebar.
  2. Click the **Files** tab.
  3. Expand **LLMServer** and drag your `.gguf` file into the list.

Once transferred, pull down to refresh the model list in the app, select the model, and tap **Load Model**.

---

## Server Usage

1. Load your chosen model in the app.
2. Tap **Start Server**.
3. The server IP and port will be displayed on screen (e.g. `http://192.168.1.50:8080`).
4. Keep the app active. Turn on **Keep Screen On** and enable **Background Audio** in the app settings for continuous operation.

---

## OpenAI-Compatible API Reference

Base URL: `http://<iphone-ip>:8080/v1`

### Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/v1/chat/completions` | Create chat completions (streaming or non-streaming) |
| `GET` | `/v1/models` | List loaded models |
| `GET` | `/` | Web dashboard displaying status and loaded model info |
| `OPTIONS` | `/*` | CORS preflight handler (returns `Access-Control-Allow-Origin: *`) |

---

### POST /v1/chat/completions

#### Request Parameters

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `messages` | Array | Yes | - | Array of message objects (`role`: `"system"` \| `"user"` \| `"assistant"`, `content`: string) |
| `model` | String | No | Loaded Model | Model identifier |
| `max_tokens` | Integer | No | `512` | Maximum generation length |
| `temperature` | Float | No | `0.7` | Sampling temperature |
| `top_p` | Float | No | `0.9` | Nucleus sampling probability cutoff |
| `stream` | Boolean | No | `false` | Enable Server-Sent Events (SSE) streaming |

---

#### 1. Non-Streaming Example

##### Request
```bash
curl http://<iphone-ip>:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-0.5b-instruct",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Why is the sky blue?"}
    ],
    "temperature": 0.7,
    "max_tokens": 128
  }'
```

##### Response
```json
{
  "id": "chatcmpl-D9F628C1-8285-407E-97F1-30A8D9F28E5B",
  "object": "chat.completion",
  "created": 1729000000,
  "model": "qwen2.5-0.5b-instruct",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "The sky appears blue because molecules in Earth's atmosphere scatter sunlight in all directions, and blue light is scattered more than other colors because it travels as shorter, smaller waves (Rayleigh scattering)."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 24,
    "completion_tokens": 36,
    "total_tokens": 60
  }
}
```

---

#### 2. Streaming Example (SSE)

##### Request
```bash
curl http://<iphone-ip>:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-0.5b-instruct",
    "messages": [
      {"role": "user", "content": "Count from 1 to 3."}
    ],
    "stream": true
  }'
```

##### Response Stream
```http
data: {"id":"chatcmpl-5775B374-1ED1-4B96-A6F7-5D9FBE4EE48F","object":"chat.completion.chunk","created":1729000000,"model":"qwen2.5-0.5b-instruct","choices":[{"index":0,"delta":{"content":"1"},"finish_reason":null}]}

data: {"id":"chatcmpl-5775B374-1ED1-4B96-A6F7-5D9FBE4EE48F","object":"chat.completion.chunk","created":1729000000,"model":"qwen2.5-0.5b-instruct","choices":[{"index":0,"delta":{"content":", 2"},"finish_reason":null}]}

data: {"id":"chatcmpl-5775B374-1ED1-4B96-A6F7-5D9FBE4EE48F","object":"chat.completion.chunk","created":1729000000,"model":"qwen2.5-0.5b-instruct","choices":[{"index":0,"delta":{"content":", 3."},"finish_reason":null}]}

data: {"id":"chatcmpl-5775B374-1ED1-4B96-A6F7-5D9FBE4EE48F","object":"chat.completion.chunk","created":1729000000,"model":"qwen2.5-0.5b-instruct","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}

data: [DONE]
```

---

### GET /v1/models

```bash
curl http://<iphone-ip>:8080/v1/models
```

##### Response
```json
{
  "object": "list",
  "data": [
    {
      "id": "qwen2.5-0.5b-instruct-q4_k_m.gguf",
      "object": "model",
      "created": 1729000000,
      "owned_by": "local"
    }
  ]
}
```

---

## Client Integration Examples

### Python (Official `openai` SDK)

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://192.168.1.50:8080/v1",
    api_key="not-needed"  # Local server does not require authentication
)

# Streaming response
stream = client.chat.completions.create(
    model="qwen2.5-0.5b-instruct",
    messages=[
        {"role": "system", "content": "You are a concise assistant."},
        {"role": "user", "content": "List three primary colors."}
    ],
    temperature=0.7,
    max_tokens=64,
    stream=True
)

for chunk in stream:
    if chunk.choices and chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
print()
```

### JavaScript / Node.js

```javascript
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "http://192.168.1.50:8080/v1",
  apiKey: "not-needed",
});

async function main() {
  const completion = await client.chat.completions.create({
    model: "qwen2.5-0.5b-instruct",
    messages: [{ role: "user", content: "Tell me a short joke." }],
    max_tokens: 100,
  });

  console.log(completion.choices[0].message.content);
}

main();
```

### Third-Party Web UIs
Connect any OpenAI-compatible client application:
- **Open WebUI**: Set `OPENAI_API_BASE_URL` to `http://<iphone-ip>:8080/v1`.
- **NextChat / ChatGPT-Next-Web**: Under Settings → Model Provider, select `OpenAI`, set Endpoint to `http://<iphone-ip>:8080`, and enter any dummy API key.
- **Chatbox**: Select `OpenAI API` provider and set Host to `http://<iphone-ip>:8080`.

---

## Terminal Chat Script

A convenience Bash script `chat.sh` is provided in the repository root:

```bash
# Set your iPhone IP
export IPHONE_IP="192.168.1.50"

# Run interactive query
./chat.sh "Explain quantum entanglement in simple words"
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        iPhone (iOS)                         │
│                                                             │
│   ┌──────────────┐                 ┌────────────────────┐   │
│   │  SwiftUI UI  │                 │    GCDWebServer    │   │
│   │ (Status, RAM,│                 │    (HTTP :8080)    │◄────── LAN Requests
│   │  Presets)    │                 │ (OpenAI Endpoints) │   │   (curl, Python, UI)
│   └──────┬───────┘                 └─────────┬──────────┘   │
│          │                                   │              │
│          └─────────────────┬─────────────────┘              │
│                            ▼                                │
│                ┌───────────────────────┐                    │
│                │       LLMEngine       │                    │
│                │ (llama.cpp C++ Metal) │                    │
│                └───────────┬───────────┘                    │
│                            ▼                                │
│                ┌───────────────────────┐                    │
│                │      model.gguf       │                    │
│                │  (Documents Sandbox)  │                    │
│                └───────────────────────┘                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
PirateLLMServer/
├── .github/workflows/
│   └── build.yml               # Automated unsigned IPA build via GitHub Actions
├── setup.sh                    # llama.cpp build orchestrator and environment setup
├── build-llama.sh              # Cross-compiles llama.cpp for iOS Device & Simulator
├── chat.sh                     # Terminal CLI client for querying the server
├── Packages/
│   └── LlamaLocal/             # Swift package wrapping llama.xcframework
├── LLMServer/
│   ├── LLMServerApp.swift      # Application entry point and shared AppState
│   ├── Info.plist              # Network permissions & file sharing declarations
│   ├── Engine/
│   │   └── LLMEngine.swift     # High-level Swift wrapper around llama.cpp Metal API
│   ├── Server/
│   │   ├── APIServer.swift     # GCDWebServer HTTP routing and SSE streaming
│   │   └── OpenAIModels.swift  # Codable OpenAI request and response schemas
│   ├── Model/
│   │   └── ModelManager.swift  # Model preset registry, URL downloader, and file storage
│   ├── Views/
│   │   └── ContentView.swift   # SwiftUI interface (presets, model manager, logs)
│   └── Utils/
│       ├── BackgroundKeepAlive.swift # Silent audio generator for persistent server uptime
│       └── NetworkInfo.swift   # Real-time memory and local Wi-Fi IP address resolution
└── LLMServer.xcodeproj/        # Xcode project configuration
```

---

## Troubleshooting & Tips

- **App Terminated with Jetsam / Memory Limit**:
  - If the app terminates abruptly upon loading a model or generating tokens, the model has exceeded iOS memory limits.
  - On a 3GB device (e.g. iPhone SE 2nd Gen), use **Qwen 2.5 0.5B** or **Llama 3.2 1B**.
  - Keep context window and max output tokens within reasonable bounds (`max_tokens: 256` or `512`).
- **Connection Refused or Timeout**:
  - Verify your client computer and iPhone are connected to the same Wi-Fi router.
  - Check your router settings for AP Isolation / Client Isolation (must be disabled for local device communication).
  - Check **Settings** → **Wi-Fi** → tap the `(i)` icon next to your network → turn off **Private Wi-Fi Address** if IP address changes unexpectedly.
- **Developer Mode Required on iOS 16 & 17**:
  - After installing via Sideloadly, you must toggle **Settings** → **Privacy & Security** → **Developer Mode** to ON and restart your phone.
- **7-Day Certificate Expiration (Free Apple ID)**:
  - Free Apple IDs require refreshing sideloaded apps every 7 days. Sideloadly can automatically refresh the app over local Wi-Fi when running in background.

---

## License

MIT License. See [LICENSE](LICENSE) for details.

## Author

Original author: **pinperepette**
