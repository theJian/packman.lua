if exists('g:loaded_lightpack') || v:version < 800
    finish
endif
let g:loaded_lightpack = 1

command! PackInit call lp#init()
command! PackLs call lp#ls()
command! PackVersion call lp#version()
command! -nargs=* PackUp call lp#up(<f-args>)
command! -nargs=* PackRm call lp#rm(<f-args>)
command! -nargs=+ PackI call lp#i(<f-args>)

command! PackList PackLs
command! PackUpdate PackUp
command! PackUpgrade PackUp
command! PackRemove PackRm
command! PackInstall PackI
