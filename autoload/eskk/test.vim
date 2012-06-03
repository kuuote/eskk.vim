" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


function! eskk#test#emulate_filter_keys(chars, ...) "{{{
    " Assumption: test case (a:chars) does not contain "(eskk:" string.

    let ret = ''
    for c in s:each_char(a:chars)
        let ret = s:emulate_char(c, ret)
    endfor

    " For convenience.
    let clear_buftable = a:0 ? a:1 : 1
    if clear_buftable
        let buftable = eskk#get_buftable()
        call buftable.clear_all()
    endif

    return ret
endfunction "}}}

function! s:each_char(chars) "{{{
    let r = split(a:chars, '\zs')
    let r = s:aggregate_backspace(r)
    return r
endfunction "}}}

function! s:aggregate_backspace(list) "{{{
    let list = a:list
    let pos = -1
    while 1
        let pos = index(list, "\x80", pos + 1)
        if pos is -1
            break
        endif
        if list[pos+1] ==# 'k' && list[pos+2] ==# 'b'
            unlet list[pos : pos+2]
            call insert(list, "\<BS>", pos)
        endif
    endwhile
    return list
endfunction "}}}

function! s:emulate_char(c, ret) "{{{
    let mapmode = eskk#map#get_map_modes()
    let c = a:c
    let ret = a:ret
    let r = eskk#filter(c)
    " NOTE: "\<Plug>" cannot be substituted by substitute().
    let r = s:remove_all_ctrl_chars(r, "\<Plug>")

    " Remove `<Plug>(eskk:_filter_redispatch_pre)` beforehand.
    let pre = ''
    if r =~# '(eskk:_filter_redispatch_pre)'
        let pre = maparg('<Plug>(eskk:_filter_redispatch_pre)', mapmode)
        let r = substitute(r, '(eskk:_filter_redispatch_pre)', '', '')
    endif

    " Remove `<Plug>(eskk:_filter_redispatch_post)` beforehand.
    let post = ''
    if r =~# '(eskk:_filter_redispatch_post)'
        let post = maparg('<Plug>(eskk:_filter_redispatch_post)', mapmode)
        let r = substitute(r, '(eskk:_filter_redispatch_post)', '', '')
    endif

    " Expand some <expr> <Plug> mappings.
    let r = substitute(
    \   r,
    \   '(eskk:expr:[^()]\+)',
    \   '\=eval(s:get_raw_map("<Plug>".submatch(0), mapmode))',
    \   'g'
    \)

    " Expand normal <Plug> mappings.
    let r = substitute(
    \   r,
    \   '(eskk:[^()]\+)',
    \   '\=s:get_raw_map("<Plug>".submatch(0), mapmode)',
    \   'g'
    \)

    let [r, ret] = s:emulate_backspace(r, ret)

    " Handle `<Plug>(eskk:_filter_redispatch_pre)`.
    if pre != ''
        let _ = eval(pre)
        let _ = s:remove_all_ctrl_chars(r, "\<Plug>")
        let [_, ret] = s:emulate_filter_char(_, ret)
        let _ = substitute(
        \   _,
        \   '(eskk:[^()]\+)',
        \   '\=s:get_raw_map("<Plug>".submatch(0), mapmode)',
        \   'g'
        \)
        let ret .= _
        let ret .= maparg(eval(pre), mapmode)
    endif

    " Handle rewritten text.
    let ret .= r

    " Handle `<Plug>(eskk:_filter_redispatch_post)`.
    if post != ''
        let _ = eval(post)
        let _ = s:remove_all_ctrl_chars(_, "\<Plug>")
        let [_, ret] = s:emulate_filter_char(_, ret)
        let _ = substitute(
        \   _,
        \   '(eskk:[^()]\+)',
        \   '\=s:get_raw_map("<Plug>".submatch(0), mapmode)',
        \   'g'
        \)
        let ret .= _
    endif

    return ret
endfunction "}}}
function! s:emulate_backspace(r, ret) "{{{
    let r = a:r
    let ret = a:ret
    for bs in ["\<BS>", "\<C-h>"]
        while 1
            let [r, pos] = s:remove_ctrl_char(r, bs)
            if pos ==# -1
                break
            endif
            if pos ==# 0
                if ret == ''
                    let r = bs . r
                    break
                else
                    let ret = eskk#util#mb_chop(ret)
                endif
            else
                let before = strpart(r, 0, pos)
                let after = strpart(r, pos)
                let before = eskk#util#mb_chop(before)
                let r = before . after
            endif
        endwhile
    endfor
    return [r, ret]
endfunction "}}}
function! s:emulate_filter_char(r, ret) "{{{
    let r = a:r
    let ret = a:ret
    while 1
        let pat = '(eskk:filter:\([^()]*\))'.'\C'
        let m = matchlist(r, pat)
        if empty(m)
            break
        endif
        let char = m[1]
        let r = substitute(r, pat, '', '')
        let _ = eskk#test#emulate_filter_keys(char, 0)
        let [_, ret] = s:emulate_backspace(_, ret)
        let r .= _
    endwhile
    return [r, ret]
endfunction "}}}

function! s:get_raw_map(...) "{{{
    return eskk#map#key2char(call('maparg', a:000))
endfunction "}}}
function! s:remove_all_ctrl_chars(s, ctrl_char) "{{{
    let s = a:s
    while 1
        let [s, pos] = s:remove_ctrl_char(s, a:ctrl_char)
        if pos == -1
            break
        endif
    endwhile
    return s
endfunction "}}}
function! s:remove_ctrl_char(s, ctrl_char) "{{{
    let s = a:s
    let pos = stridx(s, a:ctrl_char)
    if pos != -1
        let before = strpart(s, 0, pos)
        let after  = strpart(s, pos + strlen(a:ctrl_char))
        let s = before . after
    endif
    return [s, pos]
endfunction "}}}


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
