use crate::api::REQWEST_CLIENT;

use eyre::{eyre, Result};
use log::trace;
use once_cell::sync::Lazy;
use regex::Regex;
use reqwest::StatusCode;

static REGEX: Lazy<Regex> = Lazy::new(|| Regex::new(r"https://mclo\.gs/(\w+)").unwrap());

pub async fn find(content: &str) -> Result<Option<String>> {
	trace!("Checking if {content} is an mclo.gs paste");

	let Some(captures) = REGEX.captures(content) else {
		return Ok(None);
	};

	let url = format!("https://api.mclo.gs/1/raw/{}", &captures[1]);
	let request = REQWEST_CLIENT.get(&url).build()?;
	let response = REQWEST_CLIENT.execute(request).await?;
	let status = response.status();

	if let StatusCode::OK = status {
		Ok(Some(response.text().await?))
	} else {
		Err(eyre!("Failed to fetch log from {url} with {status}"))
	}
}
