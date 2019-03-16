function! packman#init()
    let s:task_id = 0
    let s:task_status_initial = 0
    let s:task_status_success = 1
    let s:task_status_failure = 2
    call s:init_installation_path()
    call s:define_commands()
endfunction

function! s:init_installation_path()
    let s:installation_path = split(&packpath, ',')[0] . '/pack/packman'
    if !isdirectory(s:installation_path)
        call mkdir(s:installation_path)
    endif
endfunction

function! s:define_commands()
    command! Pack                           call packman#open()
    command! -nargs=? -complete=file Packin call packman#install(<f-args>)
    command! -bang Packout                  call packman#output()
    command! -nargs=+ -bar Packget          call packman#get(0, <f-args>)
    command! -nargs=+ -bar Packopt          call packman#get(1, <f-args>)
    command! -nargs=+ -bar Packremove       call packman#remove(<f-args>)
endfunction

function! packman#install(...)
    let json_file = get(a:, 1, split(&packpath, ',')[0] . '/packman.json')
    let json_file = fnamemodify(json_file, ':p')
    echom json_file

    if !filereadable(json_file)
        call s:err(printf('Unable to read %s.', json_file))
        return
    endif

    let lines = readfile(json_file)
    let raw = join(lines, "")
    let json = json_decode(raw)
    let tasks = []
    let packpath = split(&packpath, ',')[0]

    for pname in keys(json)
        let pack = get(json, pname, {})
        for tname in keys(pack)
            let plugin = get(pack, tname)
            let source = get(plugin, 'source')
            let opt = get(plugin, 'opt')
            let path = packpath . '/pack/' . pname . (opt ? '/opt/' : '/start/') . tname
            let task = s:new_task(tname, source, path, opt)
            call add(tasks, task)
        endfor
    endfor

    if len(tasks)
        call s:add_tasks(tasks)
    endif
endfunction

function! packman#get(opt, ...)
    let tasks = map(copy(a:000), {-> s:new_task_from_source(v:val, a:opt)})
    call s:add_tasks(tasks)
endfunction

function! packman#remove(...)
    " TODO: implement
endfunction

function! s:get_installed_plugins()
    let start_plugins = map(filter(globpath(s:installation_path, '/start/*', 0, 1), {-> isdirectory(v:val)}), {-> s:new_plugin(simplify(v:val), 0)})
    let opt_plugins = map(filter(globpath(s:installation_path, '/opt/*', 0, 1), {-> isdirectory(v:val)}), {-> s:new_plugin(simplify(v:val), 1)})
    let plugins = start_plugins + opt_plugins
    echom string(plugins)
endfunction

function! s:new_task(name, source, path, opt)
    let s:task_id += 1
    return {
    \   'id': s:task_id,
    \   'name': a:name,
    \   'source': a:source,
    \   'path': a:path,
    \   'opt': a:opt,
    \   'status': 0,
    \   }
endfunction

function! s:new_task_from_source(source, opt)
    let name = split(a:source, '/')[-1]
    let full_source = a:source =~? '^\(http\|git@\).*' ? a:name : ('https://github.com/' . a:source)
    let path = s:installation_path . (a:opt ? '/opt' : '/start') . '/' . name
    return s:new_task(name, full_source, path, a:opt)
endfunction

function! s:new_plugin(path, opt)
    return {
    \   'name': split(a:path, '/')[-1],
    \   'path': a:path,
    \   'opt': a:opt,
    \   }
endfunction

function! s:add_tasks(tasks)
    if !exists('s:loaded_paralell_operation')
        call s:load_paralell_operation()
    endif
    execute printf("python3 submit_tasks(%s)", string(a:tasks))
endfunction

function! s:err(msg)
    echohl ErrorMsg
    echomsg '[packman] ' . a:msg
    echohl None
endfunction

function! s:load_paralell_operation()
python3 << EOF
import vim
import time
import subprocess
import os
from concurrent.futures import ThreadPoolExecutor, wait, as_completed

task_status_initial = 0
task_status_success = 0
task_status_failure = 0

executor = ThreadPoolExecutor(max_workers=2)

task_queue = []
completed_task_count = 0

def install_success_callback(task_id):
    global task_queue
    global completed_task_count
    task = next((x for x in task_queue if x["id"] == task_id and x["status"] == task_status_initial), None)
    if task:
        task["status"] = task_status_success
        completed_task_count += 1
        name = task["name"]
        total = len(task_queue)
        print("[packman] {} installed[{}/{}]".format(name, completed_task_count, total))
        if total == completed_task_count:
            task_queue.clear()
            completed_task_count = 0

def install(task):
    name = task["name"]
    dir = task["path"]
    repo_url = task["source"]
    if os.path.exists(dir):
        print("[packman] {} already installed. skipped.".format(name))
        install_success_callback(task["id"])
    else:
        cmd = "git clone {} {} --recurse-submodules --quiet".format(repo_url, dir)
        completed = subprocess.run(cmd, shell=True)
        time.sleep(1)
        install_success_callback(task["id"])


def submit_tasks(tasks):
    task_queue.extend(tasks)
    {executor.submit(install, task): task for task in tasks}

EOF
let s:loaded_paralell_operation = 1
endfunction

" ------------------------------
" function! s:getConfigFilePath()
"     let configdir = s:getPackPath()
"     let configfile = configdir . '/packman.json'
"     return configfile
" endfunction

" function! s:readConfig()
"     let configfile = s:getConfigFilePath()

"     if !filereadable(configfile)
"         call s:err(printf('Unable to read %s. Use :PackInit to generate a manifest file', configfile))
"         return
"     endif

"     let raw = readfile(configfile)
"     let config = json_decode(raw[0])
"     return config
" endfunction

" function! s:writeConfig(config)
"     let output = json_encode(a:config)
"     call writefile([output], s:getConfigFilePath())
" endfunction

" function! s:editConfigFile()
"     let configfile = s:getConfigFilePath()
"     exec ':e ' . configfile
" endfunction

" function! s:ask(message, ...)
"     call inputsave()
"     echohl WarningMsg
"     let answer = input(a:message . (a:0 ? ' (y/N/a) ' : ' (y/N) '))
"     echohl None
"     call inputrestore()
"     echon "\r\r"
"     echon ''
"     return (a:0 && answer =~? '^a') ? 2 : (answer =~? '^y') ? 1 : 0
" endfunction

" function! s:getInstalledPackages(...)
"     let type = get(a:000, 0, '*')
"     let packages = map(filter(globpath(s:getInstalledPath(), '/' . type . '/*', 0, 1), {-> isdirectory(v:val)}), {-> simplify(v:val)})
"     return packages
" endfunction

" function! s:getPackagePath(pack, type)
"     let packtype = a:type ==? 'opt' ? 'opt' : 'start'
"     let dir = simplify(s:getInstalledPath() . '/' . packtype . '/' . a:pack)
"     let installed = isdirectory(dir)
"     return { 'dir': dir, 'installed': installed }
" endfunction

" function! s:getRemoteUrl(pack)
"     let url = substitute(system('git -C ' . a:pack . ' config --get remote.origin.url') , '\n\+$', '', '')

"     if url == ""
"         call s:err('Unable to get git remote url in package: ' . a:pack)
"     endif

"     return url
" endfunction

" function! s:normalizePackageArgs(config, raw_args)
"     let packages = get(a:config, 'packages', {})
"     let args = a:raw_args

"     if len(args) > 0
"         for pack in args
"             if !has_key(packages, pack)
"                 call s:err(printf('Unable to find package %s. Use PackInstall to install plugin.', pack))
"                 return
"             endif
"         endfor
"     endif

"     if len(args) == 0
"         let args = keys(packages)
"     endif

"     return args
" endfunction

" function! lp#version()
"     echo 'packman version ' . s:version
" endfunction

" function! lp#ls()
"     let config = s:readConfig()

"     if type(config) == type({})
"         let packages = keys(get(config, 'packages', {}))
"         if len(packages) > 0
"             for pack in packages
"                 echomsg pack
"             endfor
"         else
"             echomsg "You haven't installed any plugin yet!"
"         endif
"     endif
" endfunction

" function! lp#up(...)
"     let config = s:readConfig()
"     let packages = get(config, 'packages', {})
"     let packages_to_update = s:normalizePackageArgs(config, a:000)

"     if packages_to_update is 0
"         return
"     endif

"     let total = len(packages_to_update)
"     let done = 0
"     for pack in packages_to_update
"         let source = get(packages[pack], 'source')
"         let packtype = get(packages[pack], 'opt') == v:true ? 'opt' : 'start'
"         let path = s:getPackagePath(pack, packtype)

"         if path.installed
"             echomsg printf('Updating %s (%d/%d)', pack, done, total)
"             call system('git -C ' . path.dir . ' pull --quiet --ff-only')
"         else
"             if type(source) == type('')
"                 echomsg printf('Installing %s (%d/%d)', pack, done, total)
"                 call system('git clone ' . source . ' ' . path.dir . ' --quiet')
"             endif
"         endif
"         let done = done + 1
"     endfor

"     echomsg printf('Successfully updated all %d packages', total)
" endfunction

" function! lp#rm(...)
"     let config = s:readConfig()
"     let packages = get(config, 'packages', {})
"     let packages_to_remove = s:normalizePackageArgs(config, a:000)

"     if packages_to_remove is 0
"         return
"     endif

"     let total = len(packages_to_remove)
"     let done = 0
"     for pack in packages_to_remove
"         echomsg printf('Deleting %s.', pack)
"         let packtype = get(packages[pack], 'opt') == v:true ? 'opt' : 'start'
"         let path = s:getPackagePath(pack, packtype)

"         unlet packages[pack]
"         if delete(path.dir, 'rf') != 0
"             call s:err(printf('Delete failed: %s.', pack))
"         endif
"         let done = done + 1
"     endfor

"     call s:writeConfig(config)

"     echomsg 'Successfully deleted'
" endfunction

" function! lp#i(source, ...)
"     let config = s:readConfig()
"     let packages = get(config, 'packages', {})
"     let defaultName = fnamemodify(a:source, ':t:s?\.git$??')
"     let name = get(a:000, 0, defaultName)
"     let path = s:getPackagePath(name, 'start')
"     let packages[name] = { 'source': a:source }

"     echomsg 'Downloading from ' . a:source
"     let output = system('git clone ' . a:source . ' ' . path.dir . ' --quiet')

"     if v:shell_error
"         call s:err("Download failed. \n" . output)
"         return
"     endif

"     call s:writeConfig(config)

"     echomsg printf('Successfully installed: %s', name)
" endfunction

" function! lp#init()
"     let config = s:getConfigFilePath()

"     if !filereadable(config) || s:ask('Manifest file already exists. Overwrite?')
"         let config = {}
"         let config.packages = {}
"         let packages = s:getInstalledPackages('start')
"         for pack in packages
"             let source = s:getRemoteUrl(pack)
"             if type(source) == type('') && len(source) != 0
"                 let config.packages[fnamemodify(pack, ':t')] = {
"                             \   'source': source,
"                             \   }
"             endif
"         endfor

"         let packages = s:getInstalledPackages('opt')
"         for pack in packages
"             let source = s:getRemoteUrl(pack)
"             if type(source) == type('') && len(source) != 0
"                 let config.packages[fnamemodify(pack, ':t')] = {
"                             \   'source': source,
"                             \   'opt': v:true,
"                             \   }
"             endif
"         endfor

"         call s:writeConfig(config)

"         if s:ask('Success! Created manifest file. Would you like to edit?')
"             call s:editConfigFile()
"         endif
"     endif
" endfunction
