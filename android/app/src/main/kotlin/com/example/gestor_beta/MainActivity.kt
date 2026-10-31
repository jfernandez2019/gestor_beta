// android/app/src/main/kotlin/<tu/paquete>/MainActivity.kt
// Reemplaza el contenido completo (mantén la línea "package" que ya tenías).
package com.example.gestor_beta

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity: requerido por local_auth (biometría).
// FLAG_SECURE: bloquea capturas de pantalla y oculta la app en "recientes".
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }
}
