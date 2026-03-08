import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
replacement = (
    "try:\n"
    "    from diffusers.models.controlnet import ControlNetOutput\n"
    "except ModuleNotFoundError:\n"
    "    from diffusers.models.controlnets.controlnet import ControlNetOutput"
)

# Repair duplicate/malformed try blocks first.
duplicate_try_pattern = re.compile(
    r"try:\n[ \t]*try:\n[ \t]*from diffusers\.models\.controlnet import ControlNetOutput\n[ \t]*except ModuleNotFoundError:\n[ \t]*from diffusers\.models\.controlnets\.controlnet import ControlNetOutput",
    re.MULTILINE,
)
text, _ = duplicate_try_pattern.subn(replacement, text, count=1)
block_pattern = re.compile(
    r"try:\n[ \t]*from diffusers\.models\.controlnet import ControlNetOutput\n[ \t]*except ModuleNotFoundError:\n[ \t]*from diffusers\.models\.controlnets\.controlnet import ControlNetOutput",
    re.MULTILINE,
)
text, block_replacements = block_pattern.subn(replacement, text, count=1)
if block_replacements == 0:
    text, _ = re.subn(
        r"from diffusers\.models\.controlnet import ControlNetOutput",
        replacement,
        text,
        count=1,
    )
path.write_text(text, encoding="utf-8")