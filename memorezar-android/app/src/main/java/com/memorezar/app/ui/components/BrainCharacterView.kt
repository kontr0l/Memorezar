package com.memorezar.app.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.TextUnitType
import androidx.compose.ui.unit.dp

enum class BrainCharacter(val assetName: String) {
    PRAY1("brain_pray1"),
    PRAY2("brain_pray2"),
    PRAY3("brain_pray3"),
    PRAY4("brain_pray4"),
    WORK1("brain_work1"),
    WORK2("brain_work2"),
    WORK3("brain_work3"),
    WORK4("brain_work4"),
    MISTAKE1("brain_mistake1"),
    MISTAKE2("brain_mistake2"),
    MISTAKE3("brain_mistake3"),
    MISTAKE4("brain_mistake4"),
    SPEECH("brain_speech");

    companion object {
        val heroCharacters = listOf(PRAY1, PRAY2, PRAY3, PRAY4)
        val successCharacters = listOf(WORK1, WORK2, WORK3, WORK4)
        val mistakeCharacters = listOf(MISTAKE1, MISTAKE2, MISTAKE3, MISTAKE4)

        fun randomHero(): BrainCharacter = heroCharacters.random()
        fun randomSuccess(): BrainCharacter = successCharacters.random()
        fun randomMistake(): BrainCharacter = mistakeCharacters.random()
    }
}

/**
 * Displays brain mascot sprite. Uses placeholder icon until real assets are added.
 * To add real assets: place PNGs in res/drawable/ named brain_pray1.png, etc.
 */
@Composable
fun BrainCharacterView(
    character: BrainCharacter,
    size: Dp = 120.dp,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val resId = context.resources.getIdentifier(
        character.assetName, "drawable", context.packageName
    )
    if (resId != 0) {
        Image(
            painter = painterResource(id = resId),
            contentDescription = character.assetName,
            modifier = modifier.size(size),
            contentScale = ContentScale.Fit
        )
    } else {
        Text(
            text = "\uD83E\uDDE0",
            fontSize = TextUnit(size.value * 0.6f, TextUnitType.Sp),
            modifier = modifier.size(size),
            textAlign = TextAlign.Center
        )
    }
}
