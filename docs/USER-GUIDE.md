# 📚 User Guide

## 🚀 Running a Model

To run a model, follow the instructions below.

> [!NOTE]
> You should have at least 8 GB of RAM available to run the 7B models, 16 GB to run the 13B models, and 32 GB to run the 33B models.

```bash
ollama run gemma3:4b
```

List available models:

```bash
ollama list
```

### Multiline input

For multiline input, you can wrap text with `"""`:

```bash
>>> """Hello,
... world!
... """
I'm a basic program that prints the famous "Hello, world!" message to the console.
```

### Multimodal models

```bash
ollama run gemma3:4b "What's in this image? /Users/jmorgan/Desktop/smile.png"
```

> **Output**: The image features a yellow smiley face, which is likely the central focus of the picture.

### Pass the prompt as an argument

```bash
ollama run gemma3:4b "Summarize this file: $(cat README.md)"
```

> **Output**: Ollama is a lightweight, extensible framework for building and running language models on the local machine. It provides a simple API for creating, running, and managing models, as well as a library of pre-built models that can be easily used in a variety of applications.

### Show model information

```bash
ollama show gemma3:4b
```
