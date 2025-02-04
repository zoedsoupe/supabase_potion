Deno.serve(async (req) => {
  const { error_type } = await req.json();
  
  switch (error_type) {
    case "validation":
      return new Response(JSON.stringify({
        error: "Validation failed",
        details: ["Field 'name' is required"]
      }), {
        status: 400,
        headers: { "Content-Type": "application/json" }
      });
      
    case "unauthorized":
      return new Response(JSON.stringify({
        error: "Unauthorized access"
      }), {
        status: 401,
        headers: { "Content-Type": "application/json" }
      });
      
    default:
      return new Response(JSON.stringify({
        error: "Internal server error"
      }), {
        status: 500,
        headers: { "Content-Type": "application/json" }
      });
  }
});