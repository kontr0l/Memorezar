package com.memorezar.app.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.memorezar.app.R
import com.memorezar.app.data.services.AuthService
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AuthSheet(
    authService: AuthService,
    onDismiss: () -> Unit,
    onGoogleSignIn: () -> Unit
) {
    val currentUser by authService.currentUser.collectAsState()
    val isLoading by authService.isLoading.collectAsState()
    val scope = rememberCoroutineScope()

    var isSignUp by remember { mutableStateOf(false) }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var displayName by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    // Auto-dismiss on sign-in
    LaunchedEffect(currentUser) {
        if (currentUser != null) onDismiss()
    }

    val indigo = Color(0xFF5856D6)
    val fieldShape = RoundedCornerShape(10.dp)
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
            .imePadding()
            .padding(horizontal = 20.dp)
    ) {
        Spacer(Modifier.height(12.dp))

        // Cancel pill (matches Quote Pack Request / Contact Support sheets)
        Row(modifier = Modifier.fillMaxWidth()) {
            TextButton(
                onClick = onDismiss,
                modifier = Modifier.background(pillColor, pillShape)
            ) {
                Text(stringResource(R.string.cancel), style = MaterialTheme.typography.bodyLarge)
            }
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header — indigo circle with white person icon + title + subtitle
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .background(indigo, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.Person,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(44.dp)
                )
            }
            Text(
                text = if (isSignUp) stringResource(R.string.create_account) else stringResource(R.string.sign_in),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = stringResource(R.string.sign_in_subtitle),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )

            Spacer(Modifier.height(4.dp))

            // Google Sign-In — white with outline, globe icon + text
            OutlinedButton(
                onClick = onGoogleSignIn,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                shape = RoundedCornerShape(12.dp),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    contentColor = MaterialTheme.colorScheme.onSurface
                )
            ) {
                Icon(
                    painter = painterResource(id = R.drawable.ic_google),
                    contentDescription = null,
                    tint = Color.Unspecified, // preserve Google's brand colors
                    modifier = Modifier.size(20.dp)
                )
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.sign_in_google), fontWeight = FontWeight.Medium)
            }

            // "or" divider
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                HorizontalDivider(modifier = Modifier.weight(1f))
                Text(
                    stringResource(R.string.or),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                HorizontalDivider(modifier = Modifier.weight(1f))
            }

            // Email / Password form
            if (isSignUp) {
                TextField(
                    value = displayName,
                    onValueChange = { displayName = it },
                    placeholder = { Text(stringResource(R.string.name)) },
                    shape = fieldShape,
                    colors = fieldColors,
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next)
                )
            }
            TextField(
                value = email,
                onValueChange = { email = it },
                placeholder = { Text(stringResource(R.string.email)) },
                shape = fieldShape,
                colors = fieldColors,
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Email,
                    imeAction = ImeAction.Next
                )
            )
            TextField(
                value = password,
                onValueChange = { password = it },
                placeholder = { Text(stringResource(R.string.password)) },
                shape = fieldShape,
                colors = fieldColors,
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Done
                )
            )

            errorMessage?.let {
                Text(
                    it,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                    textAlign = TextAlign.Center
                )
            }

            // Primary Sign In button — indigo pill
            Button(
                onClick = {
                    errorMessage = null
                    scope.launch {
                        try {
                            if (isSignUp) {
                                authService.signUpWithEmail(email, password, displayName)
                            } else {
                                authService.signInWithEmail(email, password)
                            }
                        } catch (e: Exception) {
                            errorMessage = e.message
                        }
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = indigo,
                    contentColor = Color.White
                ),
                enabled = email.contains("@") && password.length >= 6 && !isLoading &&
                    (!isSignUp || displayName.isNotBlank())
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp,
                        color = Color.White
                    )
                } else {
                    Text(
                        if (isSignUp) stringResource(R.string.create_account) else stringResource(R.string.sign_in),
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            // Toggle sign-in / sign-up
            TextButton(onClick = { isSignUp = !isSignUp; errorMessage = null }) {
                Text(
                    if (isSignUp) stringResource(R.string.already_have_account)
                    else stringResource(R.string.no_account),
                    color = indigo,
                    style = MaterialTheme.typography.bodySmall
                )
            }

            Spacer(Modifier.height(8.dp))
        }
    }
}
