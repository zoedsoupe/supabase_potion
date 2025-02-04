Deno.serve(async (req) => {
  return new Response("Hello from Deno!", {
    headers: { "Content-Type": "text/plain" }
  });
});