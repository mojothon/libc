from .syscalls import *

# `import *` does not re-export names beginning with an underscore, and
# `_Exit` is one: without this line the binding cannot be imported.
from .syscalls import _Exit
