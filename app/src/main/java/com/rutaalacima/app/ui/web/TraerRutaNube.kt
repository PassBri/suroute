package com.rutaalacima.app.ui.web

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CloudDownload
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rutaalacima.app.R
import com.rutaalacima.app.RutaApp
import kotlinx.coroutines.launch

/**
 * Teléfono nuevo con una cuenta que ya tiene su ruta en la nube (de la web u otro teléfono):
 * antes de sincronizar se pregunta, para que los datos de bienvenida de este teléfono no pisen los de verdad.
 * «Traer mi ruta» reemplaza lo de este teléfono por lo de la nube; «Unir» mezcla (en los choques gana este teléfono).
 */
@Composable
fun TraerRutaNube(modifier: Modifier = Modifier) {
    val c = (LocalContext.current.applicationContext as RutaApp).container
    val sesion by c.supabase.sesion.collectAsStateWithLifecycle()
    var ofrecer by remember { mutableStateOf(false) }
    var trabajando by remember { mutableStateOf(false) }
    var confirmarUnir by remember { mutableStateOf(false) }
    var aviso by remember { mutableStateOf<Pair<String, Boolean>?>(null) }
    val alcance = rememberCoroutineScope()
    val listo = stringResource(R.string.nube_listo); val error = stringResource(R.string.nube_error)
    LaunchedEffect(sesion?.userId) { ofrecer = sesion != null && c.web.nubeConRutaNueva() }
    aviso?.let { (t, esError) ->
        Text(t, modifier.padding(vertical = 6.dp), style = MaterialTheme.typography.bodyMedium,
            color = if (esError) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary)
    }
    if (!ofrecer) return
    Surface(modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.secondaryContainer) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.CloudDownload, null, tint = MaterialTheme.colorScheme.onSecondaryContainer); Spacer(Modifier.width(10.dp))
                Text(stringResource(R.string.nube_titulo), style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSecondaryContainer)
            }
            Text(stringResource(R.string.nube_texto), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSecondaryContainer)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Button(onClick = {
                    trabajando = true
                    alcance.launch {
                        val r = runCatching { c.web.traerDeLaNube() }
                        trabajando = false
                        if (r.isSuccess) { ofrecer = false; aviso = listo to false } else aviso = error to true
                    }
                }, enabled = !trabajando) {
                    if (trabajando) { CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp); Spacer(Modifier.width(8.dp)) }
                    Text(stringResource(R.string.nube_traer))
                }
                Spacer(Modifier.width(8.dp))
                TextButton(onClick = { confirmarUnir = true }, enabled = !trabajando) { Text(stringResource(R.string.nube_unir)) }
            }
        }
    }
    if (confirmarUnir) AlertDialog(onDismissRequest = { confirmarUnir = false },
        title = { Text(stringResource(R.string.nube_unir)) }, text = { Text(stringResource(R.string.nube_unir_aviso)) },
        confirmButton = { TextButton(onClick = {
            confirmarUnir = false; trabajando = true
            alcance.launch {
                val r = runCatching { c.web.unirConLaNube() }
                trabajando = false
                if (r.isSuccess) { ofrecer = false; aviso = listo to false } else aviso = error to true
            }
        }) { Text(stringResource(R.string.nube_unir)) } },
        dismissButton = { TextButton(onClick = { confirmarUnir = false }) { Text(stringResource(android.R.string.cancel)) } })
}
