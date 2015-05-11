var BG, BW, _, _s, ansi, args, bold, c, colors, dirString, dotString, extString, fg, fileArgs, fs, fw, groupName, j, len, linkString, listDir, listFiles, log, moment, nameString, ownerName, ownerString, p, path, prof, ref, ref1, reset, rightsString, rwxString, sizeString, sort, stats, str, timeString, username, util, vsprintf;

log = console.log;

prof = require('./coffee/prof');

str = require('./coffee/str');

prof('start', 'ls');

ansi = require('ansi-256-colors');

fs = require('fs');

path = require('path');

util = require('util');

_s = require('underscore.string');

_ = require('lodash');

moment = require('moment');

bold = '\x1b[1m';

reset = ansi.reset;

fg = ansi.fg.getRgb;

BG = ansi.bg.getRgb;

fw = function(i) {
  return ansi.fg.grayscale[i];
};

BW = function(i) {
  return ansi.bg.grayscale[i];
};

stats = {
  num_dirs: 0,
  num_files: 0,
  hidden_dirs: 0,
  hidden_files: 0,
  maxOwnerLength: 0,
  maxGroupLength: 0
};


/*
 0000000   00000000    0000000    0000000
000   000  000   000  000        000     
000000000  0000000    000  0000  0000000 
000   000  000   000  000   000       000
000   000  000   000   0000000   0000000
 */

args = require("nomnom").script("color-ls").options({
  paths: {
    position: 0,
    help: "the file(s) and/or folder(s) to display",
    list: true
  },
  long: {
    abbr: 'l',
    flag: true,
    help: 'include size and modification date'
  },
  owner: {
    abbr: 'o',
    flag: true,
    help: 'include owner and group'
  },
  rights: {
    abbr: 'r',
    flag: true,
    help: 'include rights'
  },
  all: {
    abbr: 'a',
    flag: true,
    help: 'show dot files'
  },
  dirs: {
    abbr: 'd',
    flag: true,
    help: "show only dirs"
  },
  files: {
    abbr: 'f',
    flag: true,
    help: "show only files"
  },
  size: {
    abbr: 's',
    flag: true,
    help: 'sort by size'
  },
  time: {
    abbr: 't',
    flag: true,
    help: 'sort by time'
  },
  kind: {
    abbr: 'k',
    flag: true,
    help: 'sort by kind'
  },
  pretty: {
    abbr: 'p',
    flag: true,
    help: 'pretty size and date'
  },
  recurse: {
    abbr: 'R',
    flag: true,
    help: 'recurse into subdirs'
  },
  stats: {
    abbr: 'i',
    flag: true,
    help: "show statistics"
  },
  bytes: {
    flag: true,
    help: 'include size',
    hidden: true
  },
  date: {
    flag: true,
    help: 'include modification date',
    hidden: true
  },
  colors: {
    flag: true,
    help: "shows available colors",
    hidden: true
  },
  values: {
    flag: true,
    help: "shows color values",
    hidden: true
  }
}).parse();

if (args.values) {
  c = require('./coffee/colors');
  c.show_values();
  process.exit(0);
}

if (args.colors) {
  c = require('./coffee/colors');
  c.show();
  process.exit(0);
}

if (args.size) {
  args.files = true;
}

if (args.long) {
  args.bytes = true;
  args.date = true;
}

if (!(((ref = args.paths) != null ? ref.length : void 0) > 0)) {
  args.paths = ['.'];
}


/*
 0000000   0000000   000       0000000   00000000    0000000
000       000   000  000      000   000  000   000  000     
000       000   000  000      000   000  0000000    0000000 
000       000   000  000      000   000  000   000       000
 0000000   0000000   0000000   0000000   000   000  0000000
 */

colors = {
  'coffee': [bold + fg(4, 4, 0), fg(1, 1, 0), fg(1, 1, 0)],
  'py': [bold + fg(0, 2, 0), fg(0, 1, 0), fg(0, 1, 0)],
  'rb': [bold + fg(4, 0, 0), fg(1, 0, 0), fg(1, 0, 0)],
  'json': [bold + fg(4, 0, 4), fg(1, 0, 1), fg(1, 0, 1)],
  'js': [bold + fg(5, 0, 5), fg(1, 0, 1), fg(1, 0, 1)],
  'cpp': [bold + fg(5, 4, 0), fw(1), fg(1, 1, 0)],
  'h': [fg(3, 1, 0), fw(1), fg(1, 1, 0)],
  'pyc': [fw(5), fw(1), fw(1)],
  'log': [fw(5), fw(1), fw(1)],
  'log': [fw(5), fw(1), fw(1)],
  'txt': [fw(20), fw(1), fw(2)],
  'md': [bold + fw(20), fw(1), fw(2)],
  'markdown': [bold + fw(20), fw(1), fw(2)],
  '_default': [fw(15), fw(1), fw(6)],
  '_dir': [bold + BG(0, 0, 2) + fw(23), fg(1, 1, 5), fg(2, 2, 5)],
  '_.dir': [bold + BG(0, 0, 1) + fw(23), fg(1, 1, 5), fg(2, 2, 5)],
  '_arrow': fw(1),
  '_header': [bold + BW(2) + fg(3, 2, 0), fw(4), bold + BW(2) + fg(5, 5, 0)],
  '_size': {
    b: [fg(0, 0, 2)],
    kB: [fg(0, 0, 4), fg(0, 0, 2)],
    MB: [fg(1, 1, 5), fg(0, 0, 3)],
    TB: [fg(4, 4, 5), fg(2, 2, 5)]
  },
  '_users': {
    root: fg(3, 0, 0),
    "default": fg(1, 0, 1)
  },
  '_groups': {
    wheel: fg(1, 0, 0),
    staff: fg(0, 1, 0),
    admin: fg(1, 1, 0),
    "default": fg(1, 0, 1)
  },
  '_rights': {
    'r+': bold + BW(1) + fg(1, 1, 1),
    'r-': reset + BW(1),
    'w+': bold + BW(1) + fg(2, 2, 5),
    'w-': reset + BW(1),
    'x+': bold + BW(1) + fg(5, 0, 0),
    'x-': reset + BW(1)
  }
};

try {
  username = require('userid').username(process.getuid());
  colors['_users'][username] = fg(0, 4, 0);
} catch (_error) {
  username = "";
}


/*
 0000000   0000000   00000000   000000000
000       000   000  000   000     000   
0000000   000   000  0000000       000   
     000  000   000  000   000     000   
0000000    0000000   000   000     000
 */

sort = function(list, stats, exts) {
  var j, k, l, ref1, ref2, results, results1;
  if (exts == null) {
    exts = [];
  }
  l = _.zip(list, stats, (function() {
    results = [];
    for (var j = 0, ref1 = list.length; 0 <= ref1 ? j < ref1 : j > ref1; 0 <= ref1 ? j++ : j--){ results.push(j); }
    return results;
  }).apply(this), exts.length > 0 && exts || (function() {
    results1 = [];
    for (var k = 0, ref2 = list.length; 0 <= ref2 ? k < ref2 : k > ref2; 0 <= ref2 ? k++ : k--){ results1.push(k); }
    return results1;
  }).apply(this));
  if (args.kind) {
    if (exts === []) {
      return list;
    }
    l.sort(function(a, b) {
      var m;
      if (a[3] > b[3]) {
        return 1;
      }
      if (a[3] < b[3]) {
        return -1;
      }
      if (args.time) {
        m = moment(a[1].mtime);
        if (m.isAfter(b[1].mtime)) {
          return 1;
        }
        if (m.isBefore(b[1].mtime)) {
          return -1;
        }
      }
      if (args.size) {
        if (a[1].size > b[1].size) {
          return 1;
        }
        if (a[1].size < b[1].size) {
          return -1;
        }
      }
      if (a[2] > b[2]) {
        return 1;
      }
      return -1;
    });
  } else if (args.time) {
    l.sort(function(a, b) {
      var m;
      m = moment(a[1].mtime);
      if (m.isAfter(b[1].mtime)) {
        return 1;
      }
      if (m.isBefore(b[1].mtime)) {
        return -1;
      }
      if (args.size) {
        if (a[1].size > b[1].size) {
          return 1;
        }
        if (a[1].size < b[1].size) {
          return -1;
        }
      }
      if (a[2] > b[2]) {
        return 1;
      }
      return -1;
    });
  } else if (args.size) {
    l.sort(function(a, b) {
      if (a[1].size > b[1].size) {
        return 1;
      }
      if (a[1].size < b[1].size) {
        return -1;
      }
      if (a[2] > b[2]) {
        return 1;
      }
      return -1;
    });
  }
  return _.unzip(l)[0];
};


/*
00000000   00000000   000  000   000  000000000
000   000  000   000  000  0000  000     000   
00000000   0000000    000  000 0 000     000   
000        000   000  000  000  0000     000   
000        000   000  000  000   000     000
 */

linkString = function(file) {
  return reset + fw(1) + fg(1, 0, 1) + " ► " + fg(4, 0, 4) + fs.readlinkSync(file);
};

nameString = function(name, ext) {
  return " " + colors[(colors[ext] != null) && ext || '_default'][0] + name + reset;
};

dotString = function(ext) {
  return colors[(colors[ext] != null) && ext || '_default'][1] + "." + reset;
};

extString = function(ext) {
  return dotString(ext) + colors[(colors[ext] != null) && ext || '_default'][2] + ext + reset;
};

dirString = function(name, ext) {
  c = name && '_dir' || '_.dir';
  return colors[c][0] + (name && " " + name || "") + (ext ? colors['_dir'][1] + '.' + colors['_dir'][2] + ext : "") + " ";
};

sizeString = function(stat) {
  if (stat.size < 1000) {
    return colors['_size']['b'][0] + _s.lpad(stat.size, 10) + " ";
  } else if (stat.size < 1000000) {
    if (args.pretty) {
      return colors['_size']['kB'][0] + _s.lpad((stat.size / 1000).toFixed(0), 7) + " " + colors['_size']['kB'][1] + "kB ";
    } else {
      return colors['_size']['kB'][0] + _s.lpad(stat.size, 10) + " ";
    }
  } else if (stat.size < 1000000000) {
    if (args.pretty) {
      return colors['_size']['MB'][0] + _s.lpad((stat.size / 1000000).toFixed(1), 7) + " " + colors['_size']['MB'][1] + "MB ";
    } else {
      return colors['_size']['MB'][0] + _s.lpad(stat.size, 10) + " ";
    }
  } else {
    if (args.pretty) {
      return colors['_size']['TB'][0] + _s.lpad((stat.size / 1000000000).toFixed(3), 7) + " " + colors['_size']['TB'][1] + "TB ";
    } else {
      return colors['_size']['TB'][0] + _s.lpad(stat.size, 10) + " ";
    }
  }
};

timeString = function(stat) {
  var col, t;
  t = moment(stat.mtime);
  return fw(16) + (args.pretty ? _s.lpad(t.format("D"), 2) : t.format("DD")) + fw(7) + '.' + (args.pretty ? fw(14) + t.format("MMM") + fw(1) + "'" : fw(14) + t.format("MM") + fw(1) + "'") + fw(4) + t.format("YY") + " " + fw(16) + t.format("hh") + (col = fw(7) + ':' + fw(14) + t.format("mm") + (col = fw(1) + ':' + fw(4) + t.format("ss") + " "));
};

ownerName = function(stat) {
  try {
    return require('userid').username(stat.uid);
  } catch (_error) {
    return stat.uid;
  }
};

groupName = function(stat) {
  try {
    return require('userid').groupname(stat.gid);
  } catch (_error) {
    return stat.gid;
  }
};

ownerString = function(stat) {
  var gcl, grp, ocl, own;
  own = ownerName(stat);
  grp = groupName(stat);
  ocl = colors['_users'][own];
  if (!ocl) {
    ocl = colors['_users']['default'];
  }
  gcl = colors['_groups'][grp];
  if (!gcl) {
    gcl = colors['_groups']['default'];
  }
  return ocl + _s.rpad(own, stats.maxOwnerLength) + " " + gcl + _s.rpad(grp, stats.maxGroupLength);
};

rwxString = function(mode, i) {
  return (((mode >> (i * 3)) & 0x4) && colors['_rights']['r+'] + ' r' || colors['_rights']['r-'] + '  ') + (((mode >> (i * 3)) & 0x2) && colors['_rights']['w+'] + ' w' || colors['_rights']['w-'] + '  ') + (((mode >> (i * 3)) & 0x1) && colors['_rights']['x+'] + ' x' || colors['_rights']['x-'] + '  ');
};

rightsString = function(stat) {
  var gr, ro, ur;
  ur = rwxString(stat.mode, 2) + " ";
  gr = rwxString(stat.mode, 1) + " ";
  ro = rwxString(stat.mode, 0) + " ";
  return ur + gr + ro + reset;
};


/*
00000000  000  000      00000000   0000000
000       000  000      000       000     
000000    000  000      0000000   0000000 
000       000  000      000            000
000       000  0000000  00000000  0000000
 */

listFiles = function(p, files) {
  var d, dirs, dsts, exts, f, fils, fsts, j, k, len, len1, results;
  dirs = [];
  fils = [];
  dsts = [];
  fsts = [];
  exts = [];
  if (args.owner) {
    files.forEach(function(rp) {
      var file, gl, ol, stat;
      if (rp[0] === '/') {
        file = path.resolve(rp);
      } else {
        file = path.join(p, rp);
      }
      try {
        stat = fs.lstatSync(file);
        ol = ownerName(stat).length;
        gl = groupName(stat).length;
        if (ol > stats.maxOwnerLength) {
          stats.maxOwnerLength = ol;
        }
        if (gl > stats.maxGroupLength) {
          return stats.maxGroupLength = gl;
        }
      } catch (_error) {

      }
    });
  }
  files.forEach(function(rp) {
    var d, ext, file, link, lstat, name, s, stat;
    if (rp[0] === '/') {
      file = path.resolve(rp);
    } else {
      file = path.join(p, rp);
    }
    try {
      lstat = fs.lstatSync(file);
      link = lstat.isSymbolicLink();
      stat = link && fs.statSync(file) || lstat;
    } catch (_error) {
      return;
    }
    d = path.parse(file);
    ext = d.ext.substr(1);
    name = d.name;
    if (name[0] === '.') {
      ext = name.substr(1) + d.ext;
      name = '';
    }
    if (name.length || args.all) {
      s = " ";
      if (args.rights) {
        s += rightsString(stat);
        s += " ";
      }
      if (args.owner) {
        s += ownerString(stat);
        s += " ";
      }
      if (args.bytes) {
        s += sizeString(stat);
      }
      if (args.date) {
        s += timeString(stat);
      }
      if (stat.isDirectory()) {
        if (!args.files) {
          s += dirString(name, ext);
          if (link) {
            s += linkString(file);
          }
          dirs.push(s + reset);
          dsts.push(stat);
          return stats.num_dirs += 1;
        } else {
          return stats.hidden_dirs += 1;
        }
      } else {
        if (!args.dirs) {
          s += nameString(name, ext);
          if (ext) {
            s += extString(ext);
          }
          if (link) {
            s += linkString(file);
          }
          fils.push(s + reset);
          fsts.push(stat);
          exts.push(ext);
          return stats.num_files += 1;
        } else {
          return stats.hidden_files += 1;
        }
      }
    } else {
      if (stat.isFile()) {
        return stats.hidden_files += 1;
      } else if (stat.isDirectory()) {
        return stats.hidden_dirs += 1;
      }
    }
  });
  if (args.size || args.kind || args.time) {
    if (dirs.length && !args.files) {
      dirs = sort(dirs, dsts);
    }
    if (fils.length) {
      fils = sort(fils, fsts, exts);
    }
  }
  for (j = 0, len = dirs.length; j < len; j++) {
    d = dirs[j];
    log(d);
  }
  results = [];
  for (k = 0, len1 = fils.length; k < len1; k++) {
    f = fils[k];
    results.push(log(f));
  }
  return results;
};


/*
0000000    000  00000000 
000   000  000  000   000
000   000  000  0000000  
000   000  000  000   000
0000000    000  000   000
 */

listDir = function(p) {
  var error, j, len, msg, pn, pr, ps, ref1, results, s, sp;
  ps = p;
  if (args.paths.length === 1 && args.paths[0] === '.' && !args.recurse) {
    log(reset);
  } else {
    s = colors['_arrow'] + "►" + colors['_header'][0] + " ";
    if (ps[0] !== '~') {
      ps = path.resolve(ps);
    }
    if (_s.startsWith(ps, process.env.PWD)) {
      ps = "./" + ps.substr(process.env.PWD.length);
    } else if (_s.startsWith(p, process.env.HOME)) {
      ps = "~" + p.substr(process.env.HOME.length);
    }
    if (ps === '/') {
      s += '/';
    } else {
      sp = ps.split('/');
      s += colors['_header'][0] + sp.shift();
      while (sp.length) {
        pn = sp.shift();
        if (pn) {
          s += colors['_header'][1] + '/';
          s += colors['_header'][sp.length === 0 && 2 || 0] + pn;
        }
      }
    }
    log(reset);
    log(s + " " + reset);
    log(reset);
  }
  try {
    listFiles(p, fs.readdirSync(p));
    if (args.recurse) {
      ref1 = fs.readdirSync(p).filter(function(f) {
        return fs.statSync(path.join(p, f)).isDirectory();
      });
      results = [];
      for (j = 0, len = ref1.length; j < len; j++) {
        pr = ref1[j];
        results.push(listDir(path.resolve(path.join(p, pr))));
      }
      return results;
    }
  } catch (_error) {
    error = _error;
    msg = error.message;
    if (_s.startsWith(msg, "EACCES")) {
      msg = "permission denied";
    }
    return log(" " + BG(5, 0, 0) + " " + fg(5, 5, 0) + bold + msg + " " + reset);
  }
};


/*
00     00   0000000   000  000   000
000   000  000   000  000  0000  000
000000000  000000000  000  000 0 000
000 0 000  000   000  000  000  0000
000   000  000   000  000  000   000
 */

fileArgs = args.paths.filter(function(f) {
  return !fs.statSync(f).isDirectory();
});

if (fileArgs.length > 0) {
  log(reset);
  listFiles(process.cwd(), fileArgs);
}

ref1 = args.paths.filter(function(f) {
  return fs.statSync(f).isDirectory();
});
for (j = 0, len = ref1.length; j < len; j++) {
  p = ref1[j];
  listDir(p);
}

log("");

if (args.stats) {
  vsprintf = require("sprintf-js").vsprintf;
  log(BW(1) + " " + fw(8) + stats.num_dirs + (stats.hidden_dirs && fw(4) + "+" + fw(5) + stats.hidden_dirs || "") + fw(4) + " dirs " + fw(8) + stats.num_files + (stats.hidden_files && fw(4) + "+" + fw(5) + stats.hidden_files || "") + fw(4) + " files " + fw(8) + vsprintf("%2.1f", prof('end', 'ls')) + fw(4) + " ms" + " " + reset);
}
