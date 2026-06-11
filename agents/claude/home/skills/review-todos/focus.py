#!/usr/bin/env python3
"""Full-screen focus display for a todo item. Waits for any keypress to dismiss."""
import os
import sys
import tty
import termios
import textwrap


def clear_screen():
    sys.stdout.write('\033[2J\033[H')
    sys.stdout.flush()


def wait_for_key():
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)


def main():
    if len(sys.argv) > 1:
        title = ' '.join(sys.argv[1:])
    else:
        title = sys.stdin.read().strip()

    if not title:
        title = 'TODO'

    try:
        cols = os.get_terminal_size().columns
        rows = os.get_terminal_size().lines
    except OSError:
        cols, rows = 80, 24

    inner_width = min(cols - 8, 72)

    tl, tr, bl, br = '╔', '╗', '╚', '╝'
    h, v = '═', '║'

    def box_line(content=''):
        return v + ' ' + content.center(inner_width) + ' ' + v

    top    = tl + h * (inner_width + 2) + tr
    bottom = bl + h * (inner_width + 2) + br

    lines = [top, box_line(), box_line()]
    for chunk in textwrap.wrap(title.upper(), inner_width):
        lines.append(box_line(chunk))
    lines += [box_line(), box_line(), bottom, '', 'Press any key to continue'.center(inner_width + 4)]

    clear_screen()

    left = max(0, (cols - inner_width - 4) // 2)
    pad = ' ' * left
    top_pad = max(0, (rows - len(lines)) // 2)

    print('\n' * top_pad, end='')
    for line in lines:
        print(pad + line)

    try:
        wait_for_key()
    except Exception:
        input()

    clear_screen()


if __name__ == '__main__':
    main()
