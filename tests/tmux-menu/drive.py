#!/usr/bin/env python3
"""Run a command in a pty, play steps, print the transcript.

usage: drive.py [--env K=V]... [--unset K]... [--argv0 NAME] [--ssh-tty] [--step S]... [--timeout N] -- cmd args...
  --argv0    argv[0] for the command, e.g. -zsh for a login shell the way sshd starts it
  --ssh-tty  set SSH_TTY to the pty of the command, the way sshd does
steps:
  expect:REGEX   wait until REGEX shows up in new output (escape codes stripped)
  send:TEXT      send TEXT; \\r \\x02 \\x03 \\x04 \\x1a escapes work
  sleep:SECS     wait
  run:CMD        run CMD with sh in the driver env
  eof            wait until the command exits
The last line is "EXIT=<code>" or "EXIT=running" (the command is then killed).
Exit code: 0 when all steps pass, 1 on a timeout.
"""
import argparse, fcntl, os, pty, re, select, shutil, signal, struct, subprocess, sys, termios, time

ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b[P^_][^\x1b]*\x1b\\|\x1b[()][0-9A-Za-z]|\x1b[=>78DEHMcNO]')


def clean(raw):
    return ANSI.sub('', raw.decode('utf-8', 'replace')).replace('\r', '')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--env', action='append', default=[])
    ap.add_argument('--unset', action='append', default=[])
    ap.add_argument('--argv0')
    ap.add_argument('--ssh-tty', action='store_true')
    ap.add_argument('--step', action='append', default=[])
    ap.add_argument('--timeout', type=float, default=6.0)
    ap.add_argument('cmd', nargs=argparse.REMAINDER)
    a = ap.parse_args()
    cmd = a.cmd[1:] if a.cmd[:1] == ['--'] else a.cmd
    exe = shutil.which(cmd[0]) or cmd[0]

    env = dict(os.environ)
    for k in a.unset:
        env.pop(k, None)
    env['TERM'] = 'xterm-256color'
    for kv in a.env:
        k, v = kv.split('=', 1)
        env[k] = v

    pid, fd = pty.fork()
    if pid == 0:
        fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack('HHHH', 24, 100, 0, 0))
        if a.ssh_tty:
            env['SSH_TTY'] = os.ttyname(0)
        os.execve(exe, [a.argv0 or cmd[0]] + cmd[1:], env)

    raw = b''
    pos = 0
    status = None

    def pump(wait):
        nonlocal raw, status
        r, _, _ = select.select([fd], [], [], wait)
        if r:
            try:
                data = os.read(fd, 65536)
            except OSError:
                data = b''
            if data:
                raw += data
                return True
        if status is None:
            p, st = os.waitpid(pid, os.WNOHANG)
            if p:
                status = os.waitstatus_to_exitcode(st)
        return False

    ok = True
    for step in a.step:
        kind, _, arg = step.partition(':')
        if kind == 'expect':
            rx = re.compile(arg)
            end = time.time() + a.timeout
            while True:
                m = rx.search(clean(raw), pos)
                if m:
                    pos = m.end()
                    break
                got = pump(0.05)
                if time.time() > end or (status is not None and not got):
                    print(f'!! timeout on step {step!r}', file=sys.stderr)
                    ok = False
                    break
        elif kind == 'send':
            os.write(fd, arg.encode().decode('unicode_escape').encode('latin-1')
                     if arg.isascii() else arg.encode())
        elif kind == 'sleep':
            end = time.time() + float(arg)
            while time.time() < end:
                pump(0.05)
        elif kind == 'run':
            subprocess.run(arg, shell=True)
        elif kind == 'eof':
            end = time.time() + a.timeout
            while status is None and time.time() < end:
                pump(0.05)
            while pump(0.05):
                pass
            if status is None:
                print(f'!! timeout on step {step!r}', file=sys.stderr)
                ok = False
        if not ok:
            break

    end = time.time() + 0.3
    while time.time() < end:
        pump(0.05)
    print(clean(raw))
    if status is None:
        print('EXIT=running')
        os.kill(pid, signal.SIGHUP)
        time.sleep(0.2)
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        os.waitpid(pid, 0)
    else:
        print(f'EXIT={status}')
    sys.exit(0 if ok else 1)


main()
