import vim, os, platform, subprocess, webbrowser, json, re, string, time
import sys
PY2 = int(sys.version[0]) == 2

vim.command("let b:pscideProjectDir = ''")

class Server(object):
  def __init__(self):
    self.dir = None
    self.port = None
    self.proc = None

  def __del__(self):
    pscide_killServer(self)

_pscide_server = Server()

def pscide_killServer(s):
  if s.proc is None: return
  s.proc.stdin.close()
  s.proc.kill()
  s.proc = None
  s.port = None
  s.dir = None

def pscide_projectDir():
  cur = vim.eval("b:pscideProjectDir")
  if cur: return cur

  projectdir = ""
  mydir = vim.eval("expand('%:p:h')")
  if PY2:
    mydir = mydir.decode(vim.eval('&encoding'))
  if not os.path.isdir(mydir): return ""

  if mydir:
    projectdir = mydir
    while True:
      parent = os.path.dirname(mydir[:-1])
      if not parent:
        break
      if os.path.isfile(os.path.join(mydir, "bower.json")):
        projectdir = mydir
        break
      mydir = parent

  vim.command("let b:pscideProjectDir = " + json.dumps(projectdir))
  return projectdir

def pscide_findServer():
    if _pscide_server.proc is not None:
        return _pscide_server.port
    if _pscide_server.proc is None:
        port = 4242
        myDir = pscide_projectDir()
        proc = pscide_startServer(port, myDir)
        if proc is None:
            return None
        _pscide_server.proc = proc
        _pscide_server.port = port
        _pscide_server.dir = myDir

def pscide_startServer(port, myDir):
  win = platform.system() == "Windows"
  env = None
  if platform.system() == "Darwin":
    env = os.environ.copy()
    env["PATH"] += ":/usr/local/bin"
  try:
    proc = subprocess.Popen(["psc-ide-server", "-p", str(port)],
                            cwd=myDir, env=env,
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, shell=win)
  except Exception as e:
    pscide_displayError("Failed to start psc-ide-server: ")
    pscide_displayError(e)
    return None
  if proc.poll() is None:
    return proc
  pscide_displayError("Failed to start psc-ide-server")
  return None

def pscide_displayError(err):
  print(str(err))
