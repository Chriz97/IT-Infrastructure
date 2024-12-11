import asyncio
from aioquic.asyncio.client import connect
from aioquic.quic.configuration import QuicConfiguration


async def main():
    host = "192.168.0.60"  # server IP
    port = 4433
    message = b"Hello from the client!"
    alpn_protocols = ["hq-29"]  # must match the Server

    configuration = QuicConfiguration(
        is_client=True,
        alpn_protocols=alpn_protocols,
        verify_mode=False
    )

    async with connect(host, port, configuration=configuration) as client:
        reader, writer = await client.create_stream()
        writer.write(message)
        await writer.drain()

        # close the stream from our side, indicating we're done sending
        writer.write_eof()

        # read the server's response
        response = await reader.read()
        print("Server responded:", response.decode('utf-8', 'ignore'))

        writer.close()
        await writer.wait_closed()


if __name__ == "__main__":
    asyncio.run(main())
