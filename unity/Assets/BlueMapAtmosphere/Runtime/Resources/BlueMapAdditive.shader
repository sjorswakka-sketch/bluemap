Shader "BlueMap/Additive"
{
    Properties { _MainTex ("Light", 2D) = "white" {} _Color ("Colour", Color) = (1,1,1,1) }
    SubShader
    {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
        Cull Off
        Lighting Off
        ZWrite Off
        ZTest Always
        Blend One One
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #include "UnityCG.cginc"
            sampler2D _MainTex;
            fixed4 _Color;
            struct v2f { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; };
            v2f vert(appdata_base v) { v2f o; o.pos = UnityObjectToClipPos(v.vertex); o.uv = v.texcoord.xy; return o; }
            // A lamp adds its warm circle on top of the darkened picture.
            fixed4 frag(v2f i) : SV_Target { fixed4 light = tex2D(_MainTex, i.uv); return fixed4(_Color.rgb * light.a * _Color.a, 1); }
            ENDCG
        }
    }
}
