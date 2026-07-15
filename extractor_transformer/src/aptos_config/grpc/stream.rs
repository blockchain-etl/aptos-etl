// Standard imports
use aptos_indexer_processor_sdk::aptos_indexer_transaction_stream::config::{
    Endpoint, ReconnectionConfig,
};
use aptos_indexer_processor_sdk::aptos_indexer_transaction_stream::utils::additional_headers::AdditionalHeaders;
use aptos_indexer_processor_sdk::aptos_indexer_transaction_stream::TransactionStreamConfig;
use aptos_indexer_processor_sdk::aptos_protos::indexer::v1::TransactionsResponse;
use std::num::ParseIntError;
use std::{ffi::OsString, time::Duration};
// Other imports
use log::{debug, error, info, warn};
use tokio::task;
use tonic::{Response, Status, Streaming};
// Local imports
use super::environment::{
    get_auth_token, get_auth_token_fallback, get_ping_interval, get_ping_timeout, get_project_name,
    get_service_address, get_service_address_fallback,
};
use aptos_indexer_processor_sdk::aptos_indexer_transaction_stream::transaction_stream::get_stream as get_aptos_stream;
// use aptos_protos::indexer::v1::TransactionsResponse;

///  Explains the error occuring during the stream
#[derive(Debug)]
pub enum StreamCreationError {
    /// Occured either because a critical value was missing from the .env or
    MissingEnv(String),
    /// Alternative
    NotUnicodeEnv(OsString),
    /// Occurs whenever we fail to parse a service addr url
    UrlParsingErr(url::ParseError),
    /// Occurs whenever we failed
    IntParsingErr(ParseIntError),
    /// Failed to respond
    BadResponse,
}

/// Returns the stream response
pub async fn get_stream_response(
    start: u64,
    end: u64,
) -> Result<Response<Streaming<TransactionsResponse>>, StreamCreationError> {
    info!("[creating a stream] Starting request for a new stream");

    let addr = get_service_address();
    let auth = String::from(get_auth_token());
    let interval = get_ping_interval();
    let timeout = get_ping_timeout();
    let projname = String::from(get_project_name());

    info!(
        "[creating a stream] Creating request (addr: {}, interval: {:?}, timeout: {:?}, project_name: {:?})",
        addr, interval, timeout, projname
    );

    let stream_config: TransactionStreamConfig = TransactionStreamConfig {
        indexer_grpc_data_service_address: addr,
        starting_version: Some(start),
        request_ending_version: Some(end),
        auth_token: Some(auth),
        indexer_grpc_http2_ping_interval_secs: interval.as_secs(),
        indexer_grpc_http2_ping_timeout_secs: timeout.as_secs(),
        indexer_grpc_response_item_timeout_secs: timeout.as_secs(),
        reconnection_config: ReconnectionConfig {
            timeout_secs: timeout.as_secs(),
            max_retries: 5,
            ..ReconnectionConfig::default()
        },
        request_name_header: projname,
        additional_headers: AdditionalHeaders::default(),
        transaction_filter: None,
        backup_endpoints: match get_service_address_fallback() {
            Some(fallback_addr) => vec![Endpoint {
                address: fallback_addr,
                auth_token: get_auth_token_fallback().clone(),
                is_primary: false,
            }],
            None => Vec::new(),
        },
        primary_failback_interval_secs: TransactionStreamConfig::default_primary_failback_interval(
        ),
    };

    let result = task::spawn(async move { get_aptos_stream(stream_config).await });

    match result.await {
        Ok(Ok(response)) => {
            debug!("[creating a stream] Received a response: {:?}", response);
            Ok(response)
        }
        Ok(Err(err)) => {
            error!("[creating a stream] Received an error response: {:?}", err);
            Err(StreamCreationError::BadResponse)
        }
        Err(error) => {
            if error.is_panic() {
                warn!("[creating a stream] Aptos get_stream panicked")
            }
            warn!(
                "[creating a stream] Failed to receive a response: {}",
                error
            );
            match get_service_address_fallback() {
                Some(fallback_addr) => {
                    info!("[creating a stream] Attempting to use fallback");
                    let interval = get_ping_interval();
                    let timeout = get_ping_timeout();
                    let projname = String::from(get_project_name());
                    let auth_fb = get_auth_token_fallback().clone().unwrap_or_default();

                    let stream_config_fb: TransactionStreamConfig = TransactionStreamConfig {
                        indexer_grpc_data_service_address: fallback_addr,
                        starting_version: Some(start),
                        request_ending_version: Some(end),
                        auth_token: Some(auth_fb),
                        indexer_grpc_http2_ping_interval_secs: interval.as_secs(),
                        indexer_grpc_http2_ping_timeout_secs: timeout.as_secs(),
                        indexer_grpc_response_item_timeout_secs: timeout.as_secs(),
                        reconnection_config: ReconnectionConfig {
                            timeout_secs: timeout.as_secs(),
                            max_retries: 5,
                            ..ReconnectionConfig::default()
                        },
                        request_name_header: projname,
                        additional_headers: AdditionalHeaders::default(),
                        transaction_filter: None,
                        backup_endpoints: Vec::new(),
                        primary_failback_interval_secs:
                            TransactionStreamConfig::default_primary_failback_interval(),
                    };

                    let result =
                        task::spawn(async move { get_aptos_stream(stream_config_fb).await });

                    match result.await {
                        Ok(Ok(response)) => {
                            info!("[creating a stream] Received response from fallback, but not original");
                            Ok(response)
                        }
                        Ok(Err(err)) => {
                            error!("[creating a stream] Aptos get_stream failed with fallback as well: {:?}", err);
                            Err(StreamCreationError::BadResponse)
                        }
                        Err(err) => {
                            if err.is_panic() {
                                warn!("[creating a stream] Aptos get_stream panicked with fallback as well");
                            }
                            warn!(
                                "[creating a stream] Aptos get_stream failed with fallback: {}",
                                err
                            );
                            Err(StreamCreationError::BadResponse)
                        }
                    }
                }
                None => Err(StreamCreationError::BadResponse),
            }
        }
    }
}

/// Requests a stream from start to end.  Returns the transactions response
#[inline]
pub async fn get_stream(
    start: u64,
    end: u64,
) -> Result<Streaming<TransactionsResponse>, StreamCreationError> {
    Ok(get_stream_response(start, end).await?.into_inner())
}

/// An enum representing all possible errors whenever dealing with [pull_from_stream].
pub enum StreamPullError {
    /// Means that that we received an error status from the grpc service.
    Status(Status),
    /// Means we exhausted (emptied) all the items from the stream.  If this was
    /// expected, you do not need to treat it as an error.
    Exhausted,
}

/// Returns a [TransactionsResponse] or a [StreamPullError].
///
/// Note that, if the stream is exhausted (no more content to pull), we will return
/// [StreamPullError::Exhausted].  Although this is an Error, as we cannot pull
/// anymore data, if the stream being exhausted is expected or acceptable, it
/// can be treated as not like an error.
pub async fn pull_from_stream(
    stream: &mut Streaming<TransactionsResponse>,
) -> Result<TransactionsResponse, StreamPullError> {
    debug!("Attempting to pull message from the server");
    match stream.message().await {
        // In this case, we successfully got the response
        Ok(Some(txresponse)) => {
            debug!("Received {} transactions", txresponse.transactions.len());
            // Send out a notice if the transaction vector is empty
            if txresponse.transactions.is_empty() {
                warn!("Received an empty tx_resposne");
            }
            Ok(txresponse)
        }
        // If we receive an error, that means we received an error status from the serverr.
        Err(status) => {
            error!(
                "Received an Error status while pulling transactions from the stream: {}",
                status
            );
            Err(StreamPullError::Status(status))
        }
        // stream returns None once it is terminated its stream and all has been returned.
        // We may want to put in some sort of check at some point to verify that all tx versions
        // have been accounted for just in case there's an early termination.
        Ok(None) => {
            info!("Exhausted current stream");
            Err(StreamPullError::Exhausted)
        }
    }
}
