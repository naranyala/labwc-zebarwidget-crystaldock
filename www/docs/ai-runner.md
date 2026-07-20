# OCWS AI Runner

The `ocws-llm-runner` is a native C/GTK3 desktop client designed to interface with a local, open-source Python LLM server. It allows you to chat with local AI models directly from your desktop and leverages integrated OCR to read text from your screen.

## Features

- **Native UI** -- A glassmorphic GTK3 chat interface matching the OCWS ecosystem.
- **Model Management** -- Scans for and allows dynamic load/eject of `.gguf` language models from `~/Models/` without restarting.
- **OCR Integration** -- A built-in OCR button triggers screen capture, extracts text using Tesseract, and pastes it into the chat prompt.
- **Session Continuity** -- The Python backend manages chat history context across multi-turn conversations.

## Installation and Setup

1. **Install Python Dependencies:**

   ```bash
   pip install llama-cpp-python
   ```

2. **Download Models:**

   Create a folder at `~/Models` and download quantized `.gguf` files (e.g., Qwen2.5-Coder-3B or LLaMA-3.1-8B).

3. **Run the Application:**

   ```bash
   ocws-llm-runner
   ```

## See Also

- `llm-runner.md` -- Full documentation with API reference
- `configuration.md` -- LLM Runner section
