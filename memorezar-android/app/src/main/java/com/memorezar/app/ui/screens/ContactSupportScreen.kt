package com.memorezar.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
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
    onDismiss: () -> Unit,
    initialReason: SupportReason? = null
) {
    val currentUser by authService.currentUser.collectAsState()
    val scope = rememberCoroutineScope()

    var reason by remember { mutableStateOf(initialReason ?: SupportReason.FEATURE_REQUEST) }
    var reasonExpanded by remember { mutableStateOf(false) }
    var email by remember { mutableStateOf(currentUser?.email ?: "") }
    var message by remember { mutableStateOf("") }
    var isSubmitting by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showSuccess by remember { mutableStateOf(false) }

    val isValid = email.contains("@") && message.isNotBlank()
    val title = if (initialReason == SupportReason.QUOTE_PACK_REQUEST) "Quote Pack Request"
        else "Contact Support"

    val fieldShape = RoundedCornerShape(12.dp)
    val fieldColors = TextFieldDefaults.colors(
        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        unfocusedIndicatorColor = Color.Transparent,
        focusedIndicatorColor = Color.Transparent
    )

    val pillShape = RoundedCornerShape(50)
    val pillColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .fillMaxHeight(0.93f)
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(0.dp)
    ) {
        Spacer(Modifier.height(12.dp))
        // Header bar — Cancel / Title / Send (matches iOS)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            TextButton(
                onClick = onDismiss,
                modifier = Modifier
                    .background(pillColor, pillShape)
            ) {
                Text("Cancel", style = MaterialTheme.typography.bodyLarge)
            }
            Text(
                title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            TextButton(
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
                enabled = isValid && !isSubmitting,
                modifier = Modifier
                    .background(pillColor, pillShape)
            ) {
                if (isSubmitting) {
                    CircularProgressIndicator(
                        modifier = Modifier.height(18.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    Text("Send", style = MaterialTheme.typography.bodyLarge)
                }
            }
        }

        // What's this about?
        Text(
            "What's this about?",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 6.dp)
        )

        // Reason picker — filled rounded style
        ExposedDropdownMenuBox(
            expanded = reasonExpanded,
            onExpandedChange = { reasonExpanded = it }
        ) {
            TextField(
                value = reason.displayName,
                onValueChange = {},
                readOnly = true,
                label = { Text("Reason") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = reasonExpanded) },
                colors = fieldColors,
                shape = fieldShape,
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

        Spacer(Modifier.height(16.dp))

        // Your Email
        Text(
            "Your Email",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 6.dp)
        )
        TextField(
            value = email,
            onValueChange = { email = it },
            placeholder = { Text("Email") },
            colors = fieldColors,
            shape = fieldShape,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )
        Text(
            "So we can get back to you.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 4.dp)
        )

        Spacer(Modifier.height(12.dp))

        // Message
        Text(
            "Message",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 6.dp)
        )
        TextField(
            value = message,
            onValueChange = { message = it },
            placeholder = { Text("") },
            colors = fieldColors,
            shape = fieldShape,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 180.dp),
            maxLines = 10
        )

        errorMessage?.let {
            Text(
                it,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 4.dp)
            )
        }

        Spacer(Modifier.height(24.dp))
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
