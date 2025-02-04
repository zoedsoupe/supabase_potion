Deno.serve(async (req) => {
  const headers = Object.fromEntries(req.headers);
  const customHeader = req.headers.get("x-custom-header") || "no custom header";
  
  return new Response(JSON.stringify({ 
    headers,
    customHeader 
  }), {
    headers: { 
      "Content-Type": "application/json",
      "X-Response-Header": "test-value"
    }
  });
});