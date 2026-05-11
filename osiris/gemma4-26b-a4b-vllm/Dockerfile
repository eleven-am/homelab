FROM vllm-node-tf5

# Gemma 4 MTP assistant checkpoints require transformers support for
# model_type=gemma4_assistant, which is newer than the 5.7.0 runtime
# currently present in the base image.
RUN pip install --no-cache-dir --upgrade \
    "https://github.com/huggingface/transformers/archive/main.tar.gz"
