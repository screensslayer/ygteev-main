// Bootstrap completed. This function is intentionally a no-op now;
// the underlying RPC has been dropped. Delete this function from the
// Supabase Dashboard whenever convenient.
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
Deno.serve(()=>new Response(JSON.stringify({
    status: 'deprecated'
  }), {
    status: 410,
    headers: {
      'Content-Type': 'application/json'
    }
  }));
