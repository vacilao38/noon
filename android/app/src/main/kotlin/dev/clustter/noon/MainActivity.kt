package dev.clustter.noon

import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import android.os.Handler
import android.os.Looper
import android.util.AtomicFile
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var exportBytes: ByteArray? = null
    private val library get() = AtomicFile(File(filesDir, "noon-workspace-v1.json"))

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.clustter.noon/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "load" -> io(result) {
                        val store = library
                        if (!store.baseFile.exists() && !File(store.baseFile.path + ".bak").exists()) null
                        else store.openRead().use { input ->
                            val buffer = java.io.ByteArrayOutputStream()
                            val chunk = ByteArray(8192)
                            while (true) {
                                val count = input.read(chunk)
                                if (count < 0) break
                                if (buffer.size() + count > 200_000) throw IllegalArgumentException("Arquivo local excede o limite.")
                                buffer.write(chunk, 0, count)
                            }
                            buffer.toString("UTF-8")
                        }
                    }
                    "save" -> {
                        val value = call.arguments as? String
                        if (value == null) result.error("ARGUMENT", "Conteúdo ausente.", null)
                        else io(result) {
                            val store = library
                            val output = store.startWrite()
                            try {
                                output.write(value.toByteArray(Charsets.UTF_8))
                                store.finishWrite(output)
                            } catch (error: Exception) {
                                store.failWrite(output)
                                throw error
                            }
                            null
                        }
                    }
                    "import", "importAsset", "export" -> {
                        if (pending != null) {
                            result.error("BUSY", "Já existe uma seleção de arquivo aberta.", null)
                        } else {
                            pending = result
                            try {
                                if (call.method == "import" || call.method == "importAsset") {
                                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                                        .addCategory(Intent.CATEGORY_OPENABLE).setType("*/*")
                                    if (call.method == "importAsset") {
                                        val type = call.argument<String>("type")
                                        if (type == "image") intent.setType("image/*")
                                        startActivityForResult(intent, 5103)
                                    } else startActivityForResult(intent, 5101)
                                } else {
                                    exportBytes = call.argument<ByteArray>("bytes")
                                        ?: throw IllegalArgumentException("Arquivo ausente.")
                                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                                        .addCategory(Intent.CATEGORY_OPENABLE)
                                        .setType(call.argument<String>("mime") ?: "application/octet-stream")
                                        .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "Projeto.noon")
                                    startActivityForResult(intent, 5102)
                                }
                            } catch (error: Exception) {
                                pending = null; exportBytes = null
                                result.error("PICKER", error.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun io(result: MethodChannel.Result, action: () -> Any?) {
        executor.execute {
            try { val value = action(); main.post { result.success(value) } }
            catch (error: Exception) { main.post { result.error("FILE", error.message, null) } }
        }
    }

    @Deprecated("Activity result bridge for FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 5101 && requestCode != 5102 && requestCode != 5103) return
        val result = pending ?: return
        val bytes = exportBytes
        pending = null; exportBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(if (requestCode == 5102) false else null)
            return
        }
        io(result) {
            if (requestCode == 5102) {
                contentResolver.openOutputStream(uri, "wt")?.use { it.write(bytes!!) }
                    ?: throw IllegalStateException("Não foi possível gravar o arquivo.")
                true
            } else {
                val input = contentResolver.openInputStream(uri)
                    ?: throw IllegalStateException("Não foi possível abrir o arquivo.")
                input.use {
                    val buffer = java.io.ByteArrayOutputStream()
                    val chunk = ByteArray(8192)
                    while (true) {
                        val n = it.read(chunk)
                        if (n < 0) break
                        if (buffer.size() + n > (if (requestCode == 5103) 12_000_000 else 65_536)) throw IllegalArgumentException("Arquivo acima do limite permitido.")
                        buffer.write(chunk, 0, n)
                    }
                    if (requestCode == 5103) {
                        var name = "Arquivo"
                        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                            if (cursor.moveToFirst()) name = cursor.getString(0) ?: name
                        }
                        mapOf("name" to name, "bytes" to buffer.toByteArray())
                    } else buffer.toString("UTF-8")
                }
            }
        }
    }
    override fun onDestroy() {
        pending?.error("CLOSED", "Seleção de arquivo interrompida.", null)
        pending = null
        executor.shutdown()
        super.onDestroy()
    }
}

