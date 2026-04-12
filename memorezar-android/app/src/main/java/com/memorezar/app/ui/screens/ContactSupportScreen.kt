package com.memorezar.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.memorezar.app.data.services.AuthService
import com.memorezar.app.data.services.SupportReason
import com.memorezar.app.data.services.SupportTicketService
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContactSupportScreen(
    authService: AuthService,
    supportTicketService: SupportTicketService,
    onDismiss: () -> Unit
) {
    val currentUser by authService.currentUser.collectAsState()
    val scope = rememberCoroutineScope()

    var reason by remember { mutableStateOf(SupportReason.FEATURE_REQUEST) }
    var reasonExpanded by remember { mutableStateOf(false) }
    var email by remember { mutableStateOf(currentUser?.email ?: "") }
    var message by remember { mutableStateOf("") }
    var isSubmitting by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showSuccess by remember { mutableStateOf(false) }

    val isValid = email.contains("@") && message.isNotBlank()

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "Contact Support",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            Icon(
                Icons.Default.Close,
                contentDescription = "Close",
                modifier = Modifier
                    .size(28.dp)
                    .clickable { onDismiss() },
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // Reason picker
        ExposedDropdownMenuBox(
            expanded = reasonExpanded,
            onExpandedChange = { reasonExpanded = it }
        ) {
            OutlinedTextField(
                value = reason.displayName,
                onValueChange = {},
                readOnly = true,
                label = { Text("Reason") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = reasonExpanded) },
                modifier = Modifier
                    .fillMaxWidth()
                    .menuAnchor()
            )
            ExposedDropdownMenu(
                expanded = reasonExpanded,
                onDismissRequest = { reasonExpanded = false }
            ) {
                SupportReason.entries.forEach { r ->
                    DropdownMenuItem(
                        text = { Text(r.displayName) },
                        onClick = {
                            reason = r
                            reasonExpanded = false
                        }
                    )
                }
            }
        }

        // Email
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("Email") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        // Message
        OutlinedTextField(
            value = message,
            onValueChange = { message = it },
            label = { Text("Message") },
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 120.dp),
            maxLines = 8
        )

        errorMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }

        Spacer(Modifier.height(8.dp))

        Button(
            onClick = {
                isSubmitting = true
                errorMessage = null
                scope.launch {
                    try {
                        supportTicketService.submitTicket(reason, message, email)
                        showSuccess = true
                    } catch (e: Exception) {
                        errorMessage = e.message ?: "Failed to submit"
                    } finally {
                        isSubmitting = false
                    }
                }
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = isValid && !isSubmitting
        ) {
            if (isSubmitting) {
                CircularProgressIndicator(modifier = Modifier.height(20.dp), strokeWidth = 2.dp)
            } else {
                Text("Send")
            }
        }
    }

    if (showSuccess) {
        AlertDialog(
            onDismissRequest = { showSuccess = false; onDismiss() },
            title = { Text("Message Sent!") },
            text = { Text("Thanks for reaching out. We'll get back to you soon.") },
            confirmButton = {
                TextButton(onClick = { showSuccess = false; onDismiss() }) { Text("OK") }
            }
        )
    }
}

private val SupportReason.displayName: String
    get() = when (this) {
        SupportReason.FEATURE_REQUEST -> "Feature Request"
        SupportReason.QUOTE_PACK_REQUEST -> "Quote Pack Request"
        SupportReason.BUG_REPORT -> "Bug Report"
        SupportReason.AWESOME -> "Just Saying Hi!"
        SupportReason.OTHER -> "Other"
    }
