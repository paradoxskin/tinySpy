function! tinySpy#intercept() abort
    let l:vscode_path = s:findVscodePath()
    if l:vscode_path == ""
        echo "[X] NO BIG_BROTHER"
        return 1
    endif
    if exists("s:vscode_path") && l:vscode_path == s:vscode_path
        call s:readJson()
        return 1
    endif
    let s:vscode_path = l:vscode_path
    let s:workspace_path = fnamemodify(l:vscode_path."/..", ":p:h")
    if s:hasTasks()
        let s:task_path = s:vscode_path . "/tasks.json"
        if s:readJson() == 1
            return 1
        endif
    else
        echo "[X] TASK NOT FOUND"
        return 1
    endif
endfunction

function! s:findVscodePath() abort
    let l:path = expand("%:p:h") . "/"
    let l:pos = len(l:path) - 1
    while l:pos >= 0
        if l:path[l:pos] == '/'
            let l:vscode_guess = l:path[:l:pos] . ".vscode"
            if isdirectory(l:vscode_guess)
                return l:vscode_guess
            endif
        endif
        let l:pos -= 1
    endwhile
    return ""
endfunction

function! s:hasTasks() abort
    return (file_readable(s:vscode_path . "/tasks.json") == 1)
endfunction

function! s:readJson() abort
    let l:content = join(readfile(s:task_path), "\n")
    let l:tasks_json = json_decode(l:content)
    if s:getTasks(l:tasks_json) == 1
        return 1
    endif
    call s:getInputs(l:tasks_json)
endfunction

function! s:getTasks(json) abort
    let s:desc_list = []
    let s:desc2command = {}
    if !has_key(a:json, "tasks")
        echo "[X] TASK NOT FOUND"
        return 1
    endif
    let l:tasks = a:json['tasks']
    for task in l:tasks
        let task = s:extractTask(task)
        let s:desc2command[task["desc"]] = task["command"]
        call add(s:desc_list, task["desc"])
    endfor
endfunction

function! s:extractTask(oriTask) abort
    let l:task = {
    \   "desc": a:oriTask["label"],
    \   "command": "echo '[X] THIS TASK NOT SUPPORT'"
    \}
    if has_key(a:oriTask, "type") && a:oriTask["type"] != "shell"
        return l:task
    endif
    if has_key(a:oriTask, "command")
        let l:task["command"] = a:oriTask["command"]
        if has_key(a:oriTask, "args")
            let l:task["command"] .= " ".join(a:oriTask["args"], " ")
        endif
    endif
    if has("unix") && has_key(a:oriTask, "linux") && has_key(a:oriTask["linux"], "command")
        let l:task["command"] = a:oriTask["linux"]["command"]
        if has_key(a:oriTask["linux"], "args")
            let l:task["command"] .= " ".join(a:oriTask["linux"]["args"], " ")
        endif
    endif
    if has("mac") && has_key(a:oriTask, "osx") && has_key(a:oriTask["osx"], "command")
        let l:task["command"] = a:oriTask["osx"]["command"]
        if has_key(a:oriTask["osx"], "args")
            let l:task["command"] .= " ".join(a:oriTask[["osx"]"args"], " ")
        endif
    endif
    if (has("win32") || has("win64")) && has_key(a:oriTask, "windows") && has_key(a:oriTask["windows"], "command")
        let l:task["command"] = a:oriTask["windows"]["command"]
        if has_key(a:oriTask["windows"], "args")
            let l:task["command"] .= " ".join(a:oriTask["windows"]["args"], " ")
        endif
    endif
    return l:task
endfunction

function! s:getInputs(json) abort
    let s:input_list = []
    let s:id2input = {}
    if !has_key(a:json, "inputs")
        return
    endif
    let l:inputs = a:json['inputs']
    for input in l:inputs
        let input = s:extractInput(input)
        let s:id2input[input["id"]] = input
    endfor
endfunction

function! s:extractInput(oriInput) abort
    let l:input = {
    \   "id": a:oriInput["id"],
    \   "arg_1": "[?] unknown: ",
    \   "arg_2": "",
    \   "func": 's:userInput'
    \}
    if a:oriInput["type"] == "promptString"
        let l:input["arg_1"] = a:oriInput["description"].": "
        if has_key(a:oriInput, "default")
            let l:input["arg_2"] = a:oriInput["default"]
        endif
        if has_key(a:oriInput, "password") && a:oriInput["password"]
            let l:input["func"] = 's:userInputSecret'
        endif
    elseif a:oriInput["type"] == "pickString"
        let l:input["arg_1"] = a:oriInput["description"].": "
        let l:input["arg_2"] = a:oriInput["options"]
        let l:input["func"] = 's:userChoice'
    elseif a:oriInput["type"] == "command"
        let l:input["arg_1"] = a:oriInput["command"]
        let l:input["arg_2"] = join(a:oriInput["args"], " ")
        let l:input["func"] = 's:userCommand'
    endif
    let l:input["func"] = funcref(l:input["func"])
    return l:input
endfunction

function! tinySpy#runTask() abort
    if !exists("s:vscode_path") && tinySpy#intercept() == 1
        return
    endif
    call s:getVar()
    let l:command = s:selectTask()
    if l:command == 1
        return
    endif
    let l:real_cmd = s:getRealCommand(l:command)
    if l:real_cmd == 1
        return
    endif
    call s:termRun(l:real_cmd)
endfunction

function! s:getVar() abort
    let l:file_path = expand("%:p")
    let l:file_relative_path = substitute(l:file_path, s:workspace_path . '/', "", "")
    let l:file_name = fnamemodify(l:file_path, ":t")
    let s:vars = {
    \   "userHome": $HOME,
    \   "workspaceFolder": s:workspace_path,
    \   "workspaceFolderBasename": fnamemodify(s:workspace_path, ":t"),
    \   "file": l:file_path,
    \   "fileWorkspaceFolder": s:workspace_path,
    \   "relativeFile": l:file_relative_path,
    \   "relativeFileDirname": fnamemodify(l:file_relative_path, ":h"),
    \   "fileBasename": l:file_name,
    \   "fileBasenameNoExtension": fnamemodify(l:file_name, ":r"),
    \   "fileDirname": fnamemodify(l:file_path, ":h"),
    \   "fileExtname": fnamemodify(l:file_name, ":e"),
    \   "lineNumber": line('.'),
    \   "selectedText": "unknown",
    \   "execPath": "unknown",
    \   "pathSeparator": '/'
    \}
    if has("win32") || has("win64")
        s:vars["pathSeparator"] = '\'
    endif
endfunction

function! s:selectTask() abort
    let l:task = s:userChoice("tasks:", s:desc_list)
    if l:task == ""
        return 1
    endif
    return s:desc2command[l:task]
endfunction

function! s:getRealCommand(command) abort
    let l:real_cmd = ""
    let l:idx = 0
    while 1
        let new_idx = match(a:command, "\${[^${}]\\+}", l:idx)
        if new_idx == -1
            let l:real_cmd .= a:command[l:idx:]
            break
        endif
        let l:format = matchstr(a:command, "\${[^${}]\\+}", l:idx)
        let l:value = s:fillFormat(l:format)
        if l:value == ""
            return 1
        endif
        let l:real_cmd .= a:command[l:idx:l:new_idx-1].l:value
        let l:idx = l:new_idx + len(l:format)
    endwhile
    return l:real_cmd
endfunction

function! s:fillFormat(format) abort
    let l:value = a:format
    let l:format = substitute(a:format, " ", "", "g")
    if match(l:format, ":") == -1
        let l:key = l:format[2:-2]
        if has_key(s:vars, l:key)
            let l:value = s:vars[l:key]
        endif
    elseif l:format[:5] == "${env:"
        let l:key = l:format[6:-2]
        let l:value = substitute(system("echo $".l:key), "\n", "", "g")
    elseif l:format[:7] == "${input:"
        let l:key = l:format[8:-2]
        if has_key(s:id2input, l:key)
            let l:input = s:id2input[l:key]
            let l:value = l:input["func"](l:input["arg_1"], l:input["arg_2"])
        endif
    endif
    return l:value
endfunction

function! s:userChoice(desc, options) abort
    echo "[?] " . a:desc
    let l:choice = system("echo \"" . join(a:options, "\n") . "\" |fzf --height=10%")
    redraw!
    return substitute(l:choice, "\n", "", "g")
endfunction

function! s:userInput(desc, default) abort
    let l:input = input(a:desc, a:default)
    return l:input
endfunction

function! s:userInputSecret(desc, default) abort
    let l:input = inputsecret(a:desc, a:default)
    return l:input
endfunction

function! s:userCommand(cmd, args) abort
    return substitute(system(cmd." ".args), "\n", "", "g")
endfunction

function! s:termRun(command) abort
    call term_start("bash -c \"cd ". s:workspace_path.";".a:command.";echo [i] done.\"", {
    \   "term_name": "~>",
    \   "term_rows": 9,
    \})
    wincmd w
endfunction
