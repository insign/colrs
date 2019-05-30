###
 0000000   0000000   000       0000000   00000000           000       0000000
000       000   000  000      000   000  000   000          000      000
000       000   000  000      000   000  0000000    000000  000      0000000
000       000   000  000      000   000  000   000          000           000
 0000000   0000000   0000000   0000000   000   000          0000000  0000000
###

startTime = process.hrtime.bigint()

{ lpad, rpad } = require 'kxk/js/str'
fs     = require 'fs'
slash  = require 'kxk/js/slash'
ansi   = require 'ansi-256-colors'
util   = require 'util'

token = {}

bold   = '\x1b[1m'
reset  = ansi.reset
fg     = ansi.fg.getRgb
BG     = ansi.bg.getRgb
fw     = (i) -> ansi.fg.grayscale[i]
BW     = (i) -> ansi.bg.grayscale[i]

stats = # counters for (hidden) dirs/files
    num_dirs:       0
    num_files:      0
    hidden_dirs:    0
    hidden_files:   0
    maxOwnerLength: 0
    maxGroupLength: 0
    brokenLinks:    []

#  0000000   00000000    0000000    0000000
# 000   000  000   000  000        000
# 000000000  0000000    000  0000  0000000
# 000   000  000   000  000   000       000
# 000   000  000   000   0000000   0000000

if module.parent.id == '.'

    karg = require 'karg'
    args = karg """
    color-ls
        paths         . ? the file(s) and/or folder(s) to display . **
        all           . ? show dot files                  . = false
        dirs          . ? show only dirs                  . = false
        files         . ? show only files                 . = false
        bytes         . ? include size                    . = false
        mdate         . ? include modification date       . = false
        long          . ? include size and date           . = false
        owner         . ? include owner and group         . = false
        rights        . ? include rights                  . = false
        size          . ? sort by size                    . = false
        time          . ? sort by time                    . = false
        kind          . ? sort by kind                    . = false
        nerdy         . ? use nerd font icons             . = false
        pretty        . ? pretty size and age             . = true
        ignore        . ? don't recurse into              . = node_modules
        info          . ? show statistics                 . = false . - I
        alphabetical  . ? don't group dirs before files   . = false . - A
        offset        . ? indent short listings           . = false . - O
        recurse       . ? recurse into subdirs            . = false . - R
        tree          . ? recurse and indent              . = false . - T
        depth         . ? recursion depth                 . = ∞     . - D
        find          . ? filter with a regexp                      . - F
        debug                                             . = false . - X
    
    version      #{require("#{__dirname}/../package.json").version}
    """
    
    if args.size
        args.files = true
    
    if args.long
        args.bytes = true
        args.mdate = true
        
    if args.tree
        args.recurse = true
        args.offset  = false
    
    if args.dirs and args.files
        args.dirs = args.files = false
        
    if args.ignore?.length
        args.ignore = args.ignore.split ' ' 
    else
        args.ignore = []
        
    if args.depth == '∞' then args.depth = Infinity
    else args.depth = Math.max 0, parseInt args.depth
    if Number.isNaN args.depth then args.depth = 0
        
    if args.debug
        { klog, noon } = require 'kxk'
        klog noon.stringify args, colors:true
    
    args.paths = ['.'] unless args.paths?.length > 0

#  0000000   0000000   000       0000000   00000000    0000000
# 000       000   000  000      000   000  000   000  000
# 000       000   000  000      000   000  0000000    0000000
# 000       000   000  000      000   000  000   000       000
#  0000000   0000000   0000000   0000000   000   000  0000000

colors =
    'coffee':   [ bold+fg(4,4,0),  fg(1,1,0), fg(1,1,0) ]
    'koffee':   [ bold+fg(5,5,0),  fg(1,0,0), fg(1,0,0) ]
    'py':       [ bold+fg(0,2,0),  fg(0,1,0), fg(0,1,0) ]
    'rb':       [ bold+fg(4,0,0),  fg(1,0,0), fg(1,0,0) ]
    'json':     [ bold+fg(4,0,4),  fg(1,0,1), fg(1,0,1) ]
    'cson':     [ bold+fg(4,0,4),  fg(1,0,1), fg(1,0,1) ]
    'noon':     [ bold+fg(4,4,0),  fg(1,1,0), fg(1,1,0) ]
    'plist':    [ bold+fg(4,0,4),  fg(1,0,1), fg(1,0,1) ]
    'js':       [ bold+fg(5,0,5),  fg(1,0,1), fg(1,0,1) ]
    'cpp':      [ bold+fg(5,4,0),  fw(1),     fg(1,1,0) ]
    'h':        [      fg(3,1,0),  fw(1),     fg(1,1,0) ]
    'pyc':      [      fw(5),      fw(1),     fw(1) ]
    'log':      [      fw(5),      fw(1),     fw(1) ]
    'log':      [      fw(5),      fw(1),     fw(1) ]
    'txt':      [      fw(20),     fw(1),     fw(2) ]
    'md':       [ bold+fw(20),     fw(1),     fw(2) ]
    'markdown': [ bold+fw(20),     fw(1),     fw(2) ]
    'sh':       [ bold+fg(5,1,0),  fg(1,0,0), fg(1,0,0) ]
    'png':      [ bold+fg(5,0,0),  fg(1,0,0), fg(1,0,0) ]
    'jpg':      [ bold+fg(0,3,0),  fg(0,1,0), fg(0,1,0) ]
    'pxm':      [ bold+fg(1,1,5),  fg(0,0,1), fg(0,0,2) ]
    'tiff':     [ bold+fg(1,1,5),  fg(0,0,1), fg(0,0,2) ]

    '_default': [      fw(15),     fw(1),     fw(6) ]
    '_dir':     [ bold+BG(0,0,2)+fw(23), fg(1,1,5), bold+BG(0,0,2)+fg(2,2,5) ]
    '_.dir':    [ bold+BG(0,0,1)+fw(23), bold+BG(0,0,1)+fg(1,1,5), bold+BG(0,0,1)+fg(2,2,5) ]
    '_link':    { 'arrow': fg(1,0,1), 'path': fg(4,0,4), 'broken': BG(5,0,0)+fg(5,5,0) }
    '_arrow':     BW(2)+fw(0)
    '_header':  [ bold+BW(2)+fg(3,2,0),  fw(4), bold+BW(2)+fg(5,5,0) ]
    '_size':    { b: [fg(0,0,3)], kB: [fg(0,0,5), fg(0,0,3)], MB: [fg(1,1,5), fg(0,0,5)], GB: [fg(4,4,5), fg(2,2,5)], TB: [fg(4,4,5), fg(2,2,5)] }
    '_users':   { root:  fg(3,0,0), default: fg(1,0,1) }
    '_groups':  { wheel: fg(1,0,0), staff: fg(0,1,0), admin: fg(1,1,0), default: fg(1,0,1) }
    '_error':   [ bold+BG(5,0,0)+fg(5,5,0), bold+BG(5,0,0)+fg(5,5,5) ]
    '_rights':
                  'r+': bold+BW(1)+fg(1,1,1)
                  'r-': reset+BW(1)
                  'w+': bold+BW(1)+fg(2,2,5)
                  'w-': reset+BW(1)
                  'x+': bold+BW(1)+fg(5,0,0)
                  'x-': reset+BW(1)

userMap = {}
username = (uid) ->
    if not userMap[uid]
        try
            childp = require 'child_process'
            userMap[uid] = childp.spawnSync("id", ["-un", "#{uid}"]).stdout.toString('utf8').trim()
        catch e
            log e
    userMap[uid]

groupMap = null
groupname = (gid) ->
    if not groupMap
        try
            childp = require 'child_process'
            gids = childp.spawnSync("id", ["-G"]).stdout.toString('utf8').split(' ')
            gnms = childp.spawnSync("id", ["-Gn"]).stdout.toString('utf8').split(' ')
            groupMap = {}
            for i in [0...gids.length]
                groupMap[gids[i]] = gnms[i]
        catch e
            log e
    groupMap[gid]

if 'function' == typeof process.getuid
    colors['_users'][username(process.getuid())] = fg(0,4,0)

# 00000000   00000000   000  000   000  000000000
# 000   000  000   000  000  0000  000     000
# 00000000   0000000    000  000 0 000     000
# 000        000   000  000  000  0000     000
# 000        000   000  000  000   000     000

log_error = () ->
    
    log " " + colors['_error'][0] + " " + bold + arguments[0] + (arguments.length > 1 and (colors['_error'][1] + [].slice.call(arguments).slice(1).join(' ')) or '') + " " + reset

linkString = (file) -> 
    
    s  = reset + fw(1) + colors['_link']['arrow'] + " ► " 
    s += colors['_link'][(file in stats.brokenLinks) and 'broken' or 'path'] 
    try
        slash = require 'kxk/js/slash'
        s += slash.path fs.readlinkSync(file)
    catch err
        s += ' ? '
    s

nameString = (name, ext) -> 
    
    if args.nerdy
        icons = require './icons'
        icon = (colors[colors[ext]? and ext or '_default'][2] + (icons.get(name, ext) ? ' ')) + ' '
    else
        icon = ''
    " " + icon + colors[colors[ext]? and ext or '_default'][0] + name + reset
    
dotString  = (ext) -> 
    
    colors[colors[ext]? and ext or '_default'][1] + "." + reset
    
extString  = (name, ext) -> 
    
    if args.nerdy and name 
        icons = require './icons'
        if icons.get(name, ext) then return ''
    dotString(ext) + colors[colors[ext]? and ext or '_default'][2] + ext + reset
    
dirString  = (name, ext) ->
    
    c = name and '_dir' or '_.dir'
    icon = args.nerdy and colors[c][2] + ' \uf413' or ''
    icon + colors[c][0] + (name and (" " + name) or " ") + (if ext then colors[c][1] + '.' + colors[c][2] + ext else "") + " "

sizeString = (stat) ->
    
    if args.pretty and stat.size == 0
        return lpad(' ', 11)
    if stat.size < 1000
        colors['_size']['b'][0] + lpad(stat.size, 10) + " "
    else if stat.size < 1000000
        if args.pretty
            colors['_size']['kB'][0] + lpad((stat.size / 1000).toFixed(0), 7) + " " + colors['_size']['kB'][1] + "kB "
        else
            colors['_size']['kB'][0] + lpad(stat.size, 10) + " "
    else if stat.size < 1000000000
        if args.pretty
            colors['_size']['MB'][0] + lpad((stat.size / 1000000).toFixed(1), 7) + " " + colors['_size']['MB'][1] + "MB "
        else
            colors['_size']['MB'][0] + lpad(stat.size, 10) + " "
    else if stat.size < 1000000000000
        if args.pretty
            colors['_size']['GB'][0] + lpad((stat.size / 1000000000).toFixed(1), 7) + " " + colors['_size']['GB'][1] + "GB "
        else
            colors['_size']['GB'][0] + lpad(stat.size, 10) + " "
    else
        if args.pretty
            colors['_size']['TB'][0] + lpad((stat.size / 1000000000000).toFixed(3), 7) + " " + colors['_size']['TB'][1] + "TB "
        else
            colors['_size']['TB'][0] + lpad(stat.size, 10) + " "

timeString = (stat) ->
    
    moment = require 'moment'
    t = moment(stat.mtime)
    if args.pretty
        age = moment().to(t, true)
        [num, range] = age.split ' '
        num = '1' if num[0] == 'a'
        if range == 'few'
            num = moment().diff t, 'seconds'
            range = 'seconds'
            fw(23) + lpad(num, 2) + ' ' + fw(16) + rpad(range, 7) + ' '
        else if range.startsWith 'year'
            fw(6) + lpad(num, 2) + ' ' + fw(3) + rpad(range, 7) + ' '
        else if range.startsWith 'month'
            fw(8) + lpad(num, 2) + ' ' + fw(4) + rpad(range, 7) + ' '
        else if range.startsWith 'day'
            fw(10) + lpad(num, 2) + ' ' + fw(6) + rpad(range, 7) + ' '
        else if range.startsWith 'hour'
            fw(15) + lpad(num, 2) + ' ' + fw(8) + rpad(range, 7) + ' '
        else
            fw(18) + lpad(num, 2) + ' ' + fw(12) + rpad(range, 7) + ' '
    else
        fw(16) + lpad(t.format("DD"),2) + fw(7)+'.' +
        fw(12) + t.format("MM") + fw(7)+"." +
        fw( 8) + t.format("YY") + ' ' +
        fw(16) + t.format("HH") + col = fw(7)+':' +
        fw(14) + t.format("mm") + col = fw(1)+':' +
        fw( 4) + t.format("ss") + ' '

ownerName = (stat) ->
    
    try
        username stat.uid
    catch
        stat.uid

groupName = (stat) ->
    
    try
        groupname stat.gid
    catch
        stat.gid

ownerString = (stat) ->
    
    own = ownerName(stat)
    grp = groupName(stat)
    ocl = colors['_users'][own]
    ocl = colors['_users']['default'] unless ocl
    gcl = colors['_groups'][grp]
    gcl = colors['_groups']['default'] unless gcl
    ocl + rpad(own, stats.maxOwnerLength) + " " + gcl + rpad(grp, stats.maxGroupLength)

rwxString = (mode, i) ->
    
    (((mode >> (i*3)) & 0b100) and colors['_rights']['r+'] + ' r' or colors['_rights']['r-'] + '  ') +
    (((mode >> (i*3)) & 0b010) and colors['_rights']['w+'] + ' w' or colors['_rights']['w-'] + '  ') +
    (((mode >> (i*3)) & 0b001) and colors['_rights']['x+'] + ' x' or colors['_rights']['x-'] + '  ')

rightsString = (stat) ->
    
    ur = rwxString(stat.mode, 2) + " "
    gr = rwxString(stat.mode, 1) + " "
    ro = rwxString(stat.mode, 0) + " "
    ur + gr + ro + reset

getPrefix = (stat, depth) ->
    
    s = ''
    if args.rights
        s += rightsString stat
        s += " "
    if args.owner
        s += ownerString stat
        s += " "
    if args.bytes
        s += sizeString stat
    if args.mdate
        s += timeString stat
        
    if depth and args.tree
        s += rpad '', depth*4
        
    if s.length == 0 and args.offset
        s += '       '
    s
    
#  0000000   0000000   00000000   000000000
# 000       000   000  000   000     000
# 0000000   000   000  0000000       000
#      000  000   000  000   000     000
# 0000000    0000000   000   000     000

sort = (list, stats, exts=[]) ->
    
    _ = require 'lodash'
    moment = require 'moment'
    
    l = _.zip list, stats, [0...list.length], (exts.length > 0 and exts or [0...list.length])
    
    if args.kind
        if exts == [] then return list
        l.sort((a,b) ->
            if a[3] > b[3] then return 1
            if a[3] < b[3] then return -1
            if args.time
                m = moment(a[1].mtime)
                if m.isAfter(b[1].mtime) then return 1
                if m.isBefore(b[1].mtime) then return -1
            if args.size
                if a[1].size > b[1].size then return 1
                if a[1].size < b[1].size then return -1
            if a[2] > b[2] then return 1
            -1)
    else if args.time
        l.sort((a,b) ->
            m = moment(a[1].mtime)
            if m.isAfter(b[1].mtime) then return 1
            if m.isBefore(b[1].mtime) then return -1
            if args.size
                if a[1].size > b[1].size then return 1
                if a[1].size < b[1].size then return -1
            if a[2] > b[2] then return 1
            -1)
    else if args.size
        l.sort((a,b) ->
            if a[1].size > b[1].size then return 1
            if a[1].size < b[1].size then return -1
            if a[2] > b[2] then return 1
            -1)
    _.unzip(l)[0]

# 000   0000000   000   000   0000000   00000000   00000000  
# 000  000        0000  000  000   000  000   000  000       
# 000  000  0000  000 0 000  000   000  0000000    0000000   
# 000  000   000  000  0000  000   000  000   000  000       
# 000   0000000   000   000   0000000   000   000  00000000  

ignore = (p) ->
    
    if slash.win()
        return true if p[0] == '$'
        return true if p == 'desktop.ini'
        return true if p.toLowerCase().startsWith 'ntuser'
    else
        return true if slash.ext(p) == 'app'
    
    return true if p in args.ignore
    false
    
# 00000000  000  000      00000000   0000000
# 000       000  000      000       000
# 000000    000  000      0000000   0000000
# 000       000  000      000            000
# 000       000  0000000  00000000  0000000

listFiles = (p, files, depth) ->
    
    alph = [] if args.alphabetical
    dirs = [] # visible dirs
    fils = [] # visible files
    dsts = [] # dir stats
    fsts = [] # file stats
    exts = [] # file extensions

    if args.owner
        
        files.forEach (rp) ->
            if slash.isAbsolute rp
                file = slash.resolve rp
            else
                file  = slash.join p, rp
            try
                stat = fs.lstatSync(file)
                ol = ownerName(stat).length
                gl = groupName(stat).length
                if ol > stats.maxOwnerLength
                    stats.maxOwnerLength = ol
                if gl > stats.maxGroupLength
                    stats.maxGroupLength = gl
            catch
                return

    files.forEach (rp) ->
        
        if slash.isAbsolute rp
            file  = slash.resolve rp
        else
            file  = slash.resolve slash.join p, rp
            
        return if ignore rp
        
        try
            lstat = fs.lstatSync file
            link  = lstat.isSymbolicLink()
            stat  = link and fs.statSync(file) or lstat
        catch
            if link
                stat = lstat
                stats.brokenLinks.push file
            else
                log_error "can't read file: ", file, link
                return

        ext  = slash.ext file
        name = slash.base file
        
        if name[0] == '.'
            ext = name.substr(1) + slash.extname file
            name = ''
            
        if name.length and name[name.length-1] != '\r' or args.all
            
            s = getPrefix stat, depth
                
            if stat.isDirectory()
                if not args.files
                    if not args.tree
                        if name.startsWith './'
                            name = name[2..]
                        
                        s += dirString name, ext
                        if link
                            s += linkString file
                        dirs.push s+reset
                        alph.push s+reset if args.alphabetical
                    dsts.push stat
                    stats.num_dirs += 1
                else
                    stats.hidden_dirs += 1
            else # if path is file
                if not args.dirs
                    s += nameString name, ext
                    if ext
                        s += extString name, ext
                    if link
                        s += linkString file
                    fils.push s+reset
                    alph.push s+reset if args.alphabetical
                    fsts.push stat
                    exts.push ext
                    stats.num_files += 1
                else
                    stats.hidden_files += 1
        else
            if stat.isFile()
                stats.hidden_files += 1
            else if stat.isDirectory()
                stats.hidden_dirs += 1

    if args.size or args.kind or args.time
        if dirs.length and not args.files
            dirs = sort dirs, dsts
        if fils.length
            fils = sort fils, fsts, exts

    if args.alphabetical
        log p for p in alph
    else
        log d for d in dirs
        log f for f in fils

# 0000000    000  00000000
# 000   000  000  000   000
# 000   000  000  0000000
# 000   000  000  000   000
# 0000000    000  000   000

listDir = (p) ->
    
    return if ignore slash.basename p
        
    if args.recurse
        depth = pathDepth p
        return if depth > args.depth
    
    ps = p

    try
        files = fs.readdirSync(p)
    catch error
        msg = error.message
        msg = "permission denied" if msg.startsWith "EACCES"
        log_error msg

    if args.find
        files = files.filter (f) ->
            f if RegExp(args.find).test f
            
    if args.find and not files.length
        true
    else if args.paths.length == 1 and args.paths[0] == '.' and not args.recurse
        log reset
    else if args.tree
        log getPrefix(slash.isDir(p), depth-1) + dirString(slash.base(ps), slash.ext(ps)) + reset
    else
        s = colors['_arrow'] + " ▶ " + colors['_header'][0]
        ps = slash.resolve ps if ps[0] != '~'
        if ps.startsWith process.env.PWD
            ps = ps.substr process.env.PWD.length+1
        else if p.startsWith process.env.HOME
            ps = "~" + p.substr process.env.HOME.length

        if ps == '/'
            s += '/'
        else
            sp = ps.split('/')
            s += colors['_header'][0] + sp.shift()
            while sp.length
                pn = sp.shift()
                if pn
                    s += colors['_header'][1] + '/'
                    s += colors['_header'][sp.length == 0 and 2 or 0] + pn
        log reset
        log s + " " + reset
        log reset

    if files.length
        listFiles p, files, depth

    if args.recurse
        
        doRecurse = (f) -> 
            return false if not args.all and f[0] == '.'
            slash.isDir slash.join p, f
            
        for pr in fs.readdirSync(p).filter doRecurse
            listDir slash.resolve slash.join p, pr
            
pathDepth = (p) ->
    
    rel = slash.relative p, process.cwd()
    return 0 if p == '.'
    rel.split('/').length

# 00     00   0000000   000  000   000
# 000   000  000   000  000  0000  000
# 000000000  000000000  000  000 0 000
# 000 0 000  000   000  000  000  0000
# 000   000  000   000  000  000   000

main = (args) ->
    
    pathstats = args.paths.map (f) ->
        try
            [f, fs.statSync(f)]
        catch error
            log_error 'no such file: ', f
            []
    
    filestats = pathstats.filter( (f) -> f.length and not f[1].isDirectory() )
    
    if filestats.length > 0
        log reset
        listFiles process.cwd(), filestats.map( (s) -> s[0] )
    
    for p in pathstats.filter( (f) -> f.length and f[1].isDirectory() )
        log '' if args.tree
        listDir p[0]
    
    log ""
    if args.info
        kstr = require 'kxk/js/str'
        log BW(1) + " " +
        fw(8) + stats.num_dirs + (stats.hidden_dirs and fw(4) + "+" + fw(5) + (stats.hidden_dirs) or "") + fw(4) + " dirs " +
        fw(8) + stats.num_files + (stats.hidden_files and fw(4) + "+" + fw(5) + (stats.hidden_files) or "") + fw(4) + " files " +
        fw(8) + kstr.time(process.hrtime.bigint()-startTime) + " " +
        reset
    
if args
    main args
else
    module.exports = main
    