package com.memorezar.app.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

private val TipYellow = Color(0xFFFFF29A)
private val TipShadow = Color(0x26000000) // 15% black

/**
 * Wraps content with a yellow post-it tooltip bubble above it.
 * The tooltip floats above without affecting layout.
 * When [wiggle] is true, applies wiggle + glow to the content.
 */
enum class TipHorizontalAlign { Center, End }

@Composable
fun ActionTip(
    text: String,
    visible: Boolean,
    wiggle: Boolean = false,
    delayMs: Long = 600L,
    horizontalAlign: TipHorizontalAlign = TipHorizontalAlign.Center,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    var showTip by remember { mutableStateOf(false) }

    LaunchedEffect(visible) {
        if (visible) {
            delay(delayMs)
            showTip = true
        } else {
            showTip = false
        }
    }

    // Wiggle animation (only when wiggle=true)
    val wiggleAngle = if (showTip && wiggle) {
        val infiniteTransition = rememberInfiniteTransition(label = "wiggle")
        val angle by infiniteTransition.animateFloat(
            initialValue = 0f,
            targetValue = 0f,
            animationSpec = infiniteRepeatable(
                animation = keyframes {
                    durationMillis = 4000
                    0f at 0 using LinearEasing
                    8f at 80 using LinearEasing
                    -8f at 160 using LinearEasing
                    6f at 240 using LinearEasing
                    -6f at 320 using LinearEasing
                    3f at 400 using LinearEasing
                    -3f at 480 using LinearEasing
                    0f at 560 using LinearEasing
                    0f at 4000 using LinearEasing
                },
                repeatMode = RepeatMode.Restart
            ),
            label = "wiggle"
        )
        angle
    } else 0f

    // Glow animation (only when wiggle=true)
    val glowAlpha = if (showTip && wiggle) {
        val infiniteTransition = rememberInfiniteTransition(label = "glow")
        val alpha by infiniteTransition.animateFloat(
            initialValue = 0.3f,
            targetValue = 0.7f,
            animationSpec = infiniteRepeatable(
                animation = tween(800),
                repeatMode = RepeatMode.Reverse
            ),
            label = "glow"
        )
        alpha
    } else 0f

    // Custom layout: measure/place content normally, overlay tooltip without affecting size
    OverlayLayout(
        modifier = modifier,
        horizontalAlign = horizontalAlign,
        overlay = {
            AnimatedVisibility(
                visible = showTip && text.isNotEmpty(),
                enter = fadeIn(tween(200)),
                exit = fadeOut(tween(200))
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(
                        modifier = Modifier
                            .shadow(4.dp, RoundedCornerShape(8.dp), ambientColor = TipShadow, spotColor = TipShadow)
                            .clip(RoundedCornerShape(8.dp))
                            .background(TipYellow)
                            .padding(horizontal = 14.dp, vertical = 10.dp)
                    ) {
                        Text(
                            text = text,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color.Black.copy(alpha = 0.85f),
                            textAlign = TextAlign.Center,
                            lineHeight = 17.sp
                        )
                    }
                    // Triangle pointer
                    Box(
                        modifier = Modifier
                            .offset(y = (-1).dp)
                            .width(14.dp)
                            .height(8.dp)
                            .clip(TriangleDown)
                            .background(TipYellow)
                    )
                }
            }
        }
    ) {
        // Content — optionally with wiggle + glow
        Box(
            modifier = Modifier.then(
                if (showTip && wiggle) Modifier
                    .rotate(wiggleAngle)
                    .shadow(
                        elevation = (glowAlpha * 12).dp,
                        shape = RoundedCornerShape(12.dp),
                        ambientColor = Color(0xFFFFC107).copy(alpha = glowAlpha),
                        spotColor = Color(0xFFFFC107).copy(alpha = glowAlpha)
                    )
                else Modifier
            )
        ) {
            content()
        }
    }
}

/**
 * Layout that sizes itself to [content] only.
 * [overlay] is measured unconstrained and placed centered above [content],
 * but does NOT affect the layout size.
 */
@Composable
private fun OverlayLayout(
    modifier: Modifier = Modifier,
    horizontalAlign: TipHorizontalAlign = TipHorizontalAlign.Center,
    overlay: @Composable () -> Unit,
    content: @Composable () -> Unit
) {
    Layout(
        contents = listOf(content, overlay),
        modifier = modifier.graphicsLayer { clip = false }
    ) { (contentMeasurables, overlayMeasurables), constraints ->
        // Measure content with incoming constraints
        val contentPlaceable = contentMeasurables.first().measure(
            constraints.copy(minHeight = 0)
        )

        // Allow overlay to be wider than content (for small icons), but cap at a sane max
        // so long text wraps to a few lines instead of running off screen.
        val overlayMaxWidth = maxOf(contentPlaceable.width, 200.dp.roundToPx())
        val overlayPlaceable = overlayMeasurables.firstOrNull()?.measure(
            constraints.copy(
                minWidth = 0,
                minHeight = 0,
                maxWidth = overlayMaxWidth,
                maxHeight = Int.MAX_VALUE
            )
        )

        // Layout reports CONTENT size only — the overlay is drawn outside layout bounds
        // (above the content). graphicsLayer{ clip = false } prevents clipping at this node.
        // Parent containers must also not clip (use Row + horizontalScroll, not LazyRow).
        layout(contentPlaceable.width, contentPlaceable.height) {
            contentPlaceable.placeRelative(0, 0)

            if (overlayPlaceable != null) {
                val x = when (horizontalAlign) {
                    TipHorizontalAlign.Center -> (contentPlaceable.width - overlayPlaceable.width) / 2
                    TipHorizontalAlign.End -> contentPlaceable.width - overlayPlaceable.width
                }
                overlayPlaceable.placeRelative(x, -overlayPlaceable.height)
            }
        }
    }
}

private val TriangleDown = GenericShape { size, _ ->
    moveTo(0f, 0f)
    lineTo(size.width, 0f)
    lineTo(size.width / 2, size.height)
    close()
}
