package com.hervoice.mobile

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

private sealed interface Screen { data object SignIn : Screen; data object Home : Screen; data object NewReport : Screen; data object Review : Screen }
private data class CaseSummary(val id: String, val status: String, val date: String)
private data class IncidentDraft(var staffReference: String = "", var course: String = "", var occurredAt: String = "", var location: String = "", var narrative: String = "")

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme { HerVoiceApp() } }
    }
}

@Composable
private fun HerVoiceApp() {
    var screen by remember { mutableStateOf<Screen>(Screen.SignIn) }
    val cases = remember { mutableStateListOf(CaseSummary("Demo case", "Submitted", "18 Sep 2026")) }
    var draft by remember { mutableStateOf(IncidentDraft()) }
    when (screen) {
        Screen.SignIn -> SignInScreen(onContinue = { screen = Screen.Home })
        Screen.Home -> HomeScreen(cases = cases, onNewReport = { draft = IncidentDraft(); screen = Screen.NewReport })
        Screen.NewReport -> ReportScreen(draft, onDraftChange = { draft = it }, onBack = { screen = Screen.Home }, onReview = { screen = Screen.Review })
        Screen.Review -> ReviewScreen(draft, onBack = { screen = Screen.NewReport }, onSubmit = {
            cases.add(0, CaseSummary("New case", "Submitted", "Just now")); screen = Screen.Home
        })
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Page(title: String, content: @Composable (PaddingValues) -> Unit) = Scaffold(topBar = { TopAppBar(title = { Text(title) }) }, content = content)

@Composable
private fun SignInScreen(onContinue: () -> Unit) = Page("HERVOICE") { padding ->
    Column(Modifier.fillMaxSize().padding(padding).padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("A private place to document and report", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text("This app does not determine whether an allegation is true. Authorised university staff handle reports through the approved process.")
        OutlinedTextField("", { }, label = { Text("University email") }, modifier = Modifier.fillMaxWidth(), enabled = false, placeholder = { Text("Connected to API in the next integration step") })
        Button(onClick = onContinue, modifier = Modifier.fillMaxWidth()) { Text("Continue with demo account") }
        Text("For the prototype, sign-in is a screen-flow demonstration. Replace this button with POST /api/v1/auth/login and secure token storage.", style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
private fun HomeScreen(cases: List<CaseSummary>, onNewReport: () -> Unit) = Page("Your private records") { padding ->
    Column(Modifier.fillMaxSize().padding(padding).padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("Your case details are visible only after you authenticate.")
        Button(onClick = onNewReport, modifier = Modifier.fillMaxWidth()) { Text("Document an incident") }
        Text("Submitted cases", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        cases.forEach { item -> Card(Modifier.fillMaxWidth()) { Column(Modifier.padding(16.dp)) { Text(item.status, fontWeight = FontWeight.Bold); Text(item.date) } } }
        Text("Notifications will use neutral wording, for example: “You have a new confidential update.”", style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
private fun ReportScreen(draft: IncidentDraft, onDraftChange: (IncidentDraft) -> Unit, onBack: () -> Unit, onReview: () -> Unit) = Page("Document incident") { padding ->
    val scroll = rememberScrollState()
    Column(Modifier.fillMaxSize().padding(padding).padding(20.dp).verticalScroll(scroll), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Save only what you feel safe sharing. Location is optional.")
        FormField("Staff reference or name", draft.staffReference) { onDraftChange(draft.copy(staffReference = it)) }
        FormField("Course or unit optional", draft.course) { onDraftChange(draft.copy(course = it)) }
        FormField("Date and time e.g. 18 Sep 2026 14:30", draft.occurredAt) { onDraftChange(draft.copy(occurredAt = it)) }
        FormField("Location optional", draft.location) { onDraftChange(draft.copy(location = it)) }
        OutlinedTextField(draft.narrative, { onDraftChange(draft.copy(narrative = it)) }, label = { Text("What happened") }, minLines = 5, modifier = Modifier.fillMaxWidth())
        Text("Evidence picker and encrypted offline drafts are the next implementation slice. Do not capture recordings inside the app for this prototype.", style = MaterialTheme.typography.bodySmall)
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { OutlinedButton(onClick = onBack, modifier = Modifier.weight(1f)) { Text("Save draft") }; Button(onClick = onReview, modifier = Modifier.weight(1f), enabled = draft.staffReference.isNotBlank() && draft.narrative.isNotBlank()) { Text("Review") } }
    }
}

@Composable
private fun ReviewScreen(draft: IncidentDraft, onBack: () -> Unit, onSubmit: () -> Unit) = Page("Review report") { padding ->
    Column(Modifier.fillMaxSize().padding(padding).padding(20.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("Check this before submitting", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text("Staff reference: ${draft.staffReference}")
        Text("When: ${draft.occurredAt.ifBlank { "Not provided" }}")
        Text("Location: ${draft.location.ifBlank { "Not provided" }}")
        Text(draft.narrative)
        Text("Submitting sends this report to authorised personnel. It is recorded as an allegation and is not a finding of misconduct.")
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { OutlinedButton(onClick = onBack, modifier = Modifier.weight(1f)) { Text("Edit") }; Button(onClick = onSubmit, modifier = Modifier.weight(1f)) { Text("Submit report") } }
    }
}

@Composable
private fun FormField(label: String, value: String, onValueChange: (String) -> Unit) = OutlinedTextField(value, onValueChange, label = { Text(label) }, modifier = Modifier.fillMaxWidth())
