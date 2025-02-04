Deno.serve(async (req) => {
  const data = await req.arrayBuffer();
  // Reverse the binary data as an example transformation
  const reversed = new Uint8Array(data).reverse();
  
  return new Response(reversed, {
    headers: { "Content-Type": "application/octet-stream" }
  });
});