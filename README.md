# pushmi-pullyu
Ruby application to manage flow of content from Fedora into Swift for preservation

pushmi-pullyu will be a Ruby application, running behind the firewall that protects our Swift environment.

## Workflow:

- pushmi-pullyu opens a connection to Fedora's JMS service, so that it receives JMS messages broadcast by Fedora to trigger preservation operations. JMS guarantees at-least-one-time delivery of messages, so if the connection is broken messages will not be lost; they will queue up until the connection is reestablished.
- Fedora will broadcast a message requesting preservation for an object whenever an object changes. (**Spike**: determine what Fedora events constitute a change for preservation purposes. For example, we want only one preservation request to be made at the end of a deposit operation in HydraNorth, although that deposit operation might entail multiple change events from Fedora's point of view.)
- On receipt of a preservation request, pushmi-pullyu will retrieve the content from Fedora (datastream and metadata), compose an AIP according to the light-weight AIP spec to be established (**Spike**), and push that AIP into Swift. 
- On completion of a preservation operation, pushmi-pullyu will write an audit record back to Fedora's item-level audit trail, recording the results of this operation (**Spike**: figure out Fedora 4 audit trails). The audit record will have any AIP-level checksums that Fedora doesn't already have. It will log operations in a reasonably human-readable form for monitoring. (A dashboard or report generator is out of scope for now.)
- Automated recovery from failed preservation operations is out of scope for now; we'll rely on grepping the logs for failures and manually retriggering the preservation request.
- An audit process will be available to compare Fedora content with Swift, to detect Fedora objects that are not present in Swift or that have checksums that do not match Fedora's, and also to detect Swift objects that are not present in Fedora.


