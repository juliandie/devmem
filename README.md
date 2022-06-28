# devmem
Originally written by, and hosted at, www.lartmaker.nl/lartware/  

# Build
```
make
```

# Usage
```
./devmem [-rw] <address> [<width> <value>]
```
-r read advanced, append "0x" post the output value.
-w write only, do not read back a written value.
width sets the read/write width in bytes.
value is a value to be written to address.
