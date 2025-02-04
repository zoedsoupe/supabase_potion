Deno.serve(async (req) => {
  const stream = new ReadableStream({
    start(controller) {
      let count = 0;
      const interval = setInterval(() => {
        if (count >= 5) {
          clearInterval(interval);
          controller.close();
          return;
        }
        const message = `Event ${count}\n`;
        controller.enqueue(new TextEncoder().encode(message));
        count++;
      }, 1000);
    }
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive"
    }
  });
});