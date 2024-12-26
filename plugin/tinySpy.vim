if exists("g:tinySpyLoaded")
    finish
endif

command! TinySpyReset call tinySpy#intercept()
command! TinySpy call tinySpy#runTask()

let g:tinySpyLoaded = 1
