
´
transactions.protoaptos.transactions"Ä
Transaction!
block_height (RblockHeight'
block_timestamp (	RblockTimestamp
tx_type (	RtxType

tx_version (R	txVersion
tx_hash (	RtxHash*
state_change_hash (	RstateChangeHash&
event_root_hash (	ReventRootHash2
state_checkpoint_hash (	RstateCheckpointHash
gas_used	 (RgasUsed
success
 (Rsuccess
	vm_status (	RvmStatus2
accumulator_root_hash (	RaccumulatorRootHash'
sequence_number (RsequenceNumber$
max_gas_amount (RmaxGasAmount
sender (	Rsender

num_events (R	numEventsQ
num_changes (20.aptos.transactions.Transaction.ChangesAggregateR
numChanges1
expiration_timestamp (	RexpirationTimestampA
payload (2'.aptos.transactions.Transaction.PayloadRpayload$
gas_unit_price (RgasUnitPrice!
payload_type (	RpayloadType^
block_unixtimestamp (2-.aptos.transactions.Transaction.UnixTimestampRblockUnixtimestamph
expiration_unixtimestamp (2-.aptos.transactions.Transaction.UnixTimestampRexpirationUnixtimestamp%
num_signatures (RnumSignaturesñ
ChangesAggregate
total (Rtotal#
delete_module (RdeleteModule'
delete_resource (RdeleteResource*
delete_table_item (RdeleteTableItem!
write_module (RwriteModule%
write_resource (RwriteResource(
write_table_item (RwriteTableItemî
Payload
function (	Rfunction%
type_arguments (	RtypeArguments
	arguments (	R	arguments

execute_as (	R	executeAs1
entry_function_id_str (	RentryFunctionIdStr@
code (2,.aptos.transactions.Transaction.Payload.CodeRcode)
multisig_address (	RmultisigAddress”
ExposedFunction
name (	Rname

visibility (	R
visibility
is_entry (RisEntryÅ
generic_type_params (2Q.aptos.transactions.Transaction.Payload.ExposedFunction.GenericFunctionTypeParamsRgenericTypeParams
params (	Rparams
return (	Rreturn=
GenericFunctionTypeParams 
constraints (	Rconstraintsm
Code
bytecode (	RbytecodeI
abi (27.aptos.transactions.Transaction.Payload.ExposedFunctionRabil
	TxPayload
function (	Rfunction%
type_arguments (	RtypeArguments
	arguments (	R	arguments6
Module
address (	Raddress
name (	Rname?
UnixTimestamp
seconds (Rseconds
nanos (Rnanos"X
TxType
user
genesis
block_metadata
state_checkpoint
	validator"r
PayloadType
entry_function

script
module_bundle
multisig
writeset
genesis_writeset