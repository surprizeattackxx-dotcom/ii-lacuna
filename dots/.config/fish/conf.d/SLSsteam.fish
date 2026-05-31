function steam --wraps steam
    env LD_AUDIT="/usr/lib32/libSLS-library-inject.so:/usr/lib32/libSLSsteam.so" /usr/bin/steam $argv
end
