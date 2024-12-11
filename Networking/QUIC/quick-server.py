#
#
#

import asyncio
from aioquic.asyncio import serve
from aioquic.quic.configuration import QuicConfiguration

async def test_handler_coro(reader, writer):
    data = await reader.read()
    print(f"Received: {data.decode('utf-8', errors='ignore')}")

    # Write a response
    writer.write(b"Hello from the server!")
    # Signal that no more data will be sent
    writer.write_eof()
    # The QUIC implementation will handle closing the stream.

def test_handler(reader, writer):
    asyncio.create_task(test_handler_coro(reader, writer))

async def main():
    configuration = QuicConfiguration(
        is_client=False,
        alpn_protocols=["hq-29"]  # Make sure this matches the client's ALPN
    )
    configuration.load_cert_chain("server_cert.pem", "server_key.pem")

    print("Starting QUIC test server on 0.0.0.0:4433...")
    await serve(
        "0.0.0.0",
        4433,
        configuration=configuration,
        stream_handler=test_handler
    )

    # Keep the server running indefinitely
    await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
