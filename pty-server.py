#!/usr/bin/env python3
import asyncio
import os
import pty
import shlex
import signal
import sys
import termios
import tty
from asyncio import StreamReader

import websockets


async def handle_client(websocket):
    pid, master_fd = pty.fork()
    if pid == 0:
        # Child: exec bash
        os.execvp('bash', ['bash'])
        return

    # Parent: bridge between ws and pty
    loop = asyncio.get_event_loop()

    async def read_pty():
        while True:
            try:
                data = await loop.run_in_executor(None, os.read, master_fd, 1024)
                if not data:
                    break
                try:
                    await websocket.send(data.decode(errors='ignore'))
                except Exception:
                    break
            except Exception:
                break

    async def read_ws():
        async for message in websocket:
            if isinstance(message, str):
                os.write(master_fd, message.encode())
            else:
                os.write(master_fd, message)

    try:
        reader_task = asyncio.create_task(read_pty())
        writer_task = asyncio.create_task(read_ws())
        done, pending = await asyncio.wait({reader_task, writer_task}, return_when=asyncio.FIRST_COMPLETED)
    finally:
        try:
            os.close(master_fd)
        except Exception:
            pass
        try:
            os.kill(pid, signal.SIGKILL)
        except Exception:
            pass


async def main():
    port = int(os.environ.get('PTY_PORT', '8092'))
    async with websockets.serve(handle_client, '0.0.0.0', port, max_size=None, ping_interval=30):
        print(f"PTY server listening on {port}")
        await asyncio.Future()


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass



