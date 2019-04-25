function! packman#init()
    let s:task_id = 0
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
    command! -bang Packout                  call packman#export(<bang>0)
    command! -nargs=+ -bar Packget          call packman#get(0, <f-args>)
    command! -nargs=+ -bar Packopt          call packman#get(1, <f-args>)
    command! -nargs=+ -bar Packremove       call packman#remove(<f-args>)
endfunction

function! packman#install(...)
    let json_file = get(a:, 1, split(&packpath, ',')[0] . '/packman.json')
    let json_file = fnamemodify(json_file, ':p')

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

function! packman#export(force)
    let packpath = split(&packpath, ',')[0]
    let json_file = packpath . '/packman.json'
    let json_file = fnamemodify(json_file, ':p')

    if !a:force && filereadable(json_file)
        call s:err(printf("File exists. Please consider to remove %s or use \":Packout!\"", json_file))
        return
    endif

    let dict = {}
    let packdirs = filter(globpath(packpath, 'pack/*', 0, 1), {-> isdirectory(v:val)})
    for packdir in packdirs
        let start_plugin_dirs = filter(globpath(packdir, 'start/*', 0, 1), {-> isdirectory(v:val)})
        let opt_plugin_dirs = filter(globpath(packdir, 'opt/*', 0, 1), {-> isdirectory(v:val)})
        let start_plugins = map(start_plugin_dirs, {-> s:new_plugin(simplify(v:val), 0)})
        let opt_plugins = map(opt_plugin_dirs, {-> s:new_plugin(simplify(v:val), 1)})
        let plugins = start_plugins + opt_plugins

        let child_dict = {}
        for plugin in plugins
            let name = plugin["name"]
            let child_dict[name] = plugin
        endfor

        if len(child_dict)
            let packname = fnamemodify(packdir, ":t")
            let dict[packname] = child_dict
        endif
    endfor

    let content = json_encode(dict)
    call writefile([content], json_file)
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
    let source = trim(system(printf("cd %s && git config --get remote.origin.url", a:path)))
    return {
    \   'name': fnamemodify(a:path, ":t"),
    \   'source': source,
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

executor = ThreadPoolExecutor(max_workers=4)

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
