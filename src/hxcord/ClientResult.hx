package hxcord;

/**
	Outcome of an asynchronous SDK call, mirroring `discordpp::ClientResult`.

	Most SDK operations are asynchronous: you pass a callback and the SDK reports
	the outcome later, while `Client.runCallbacks()` is being pumped.
**/
class ClientResult {
	/** True when the call succeeded. Always check this before reading any data. **/
	public final successful:Bool;

	/** Category of the failure, `None` on success. **/
	public final type:ErrorType;

	/** Human readable error text. **/
	public final error:String;

	/** SDK/HTTP specific error code, `0` when unused. **/
	public final errorCode:Int;

	/** Numeric HTTP status, `0` when the call never reached Discord's servers. **/
	public final httpStatus:Int;

	/** True when retrying the same call later may succeed. **/
	public final retryable:Bool;

	/** Seconds to wait before retrying, when rate limited (HTTP 429). **/
	public final retryAfter:Float;

	public function new(successful:Bool, type:ErrorType = ErrorType.None, error:String = "", errorCode:Int = 0, httpStatus:Int = 0,
			retryable:Bool = false, retryAfter:Float = 0) {
		this.successful = successful;
		this.type = type;
		this.error = error;
		this.errorCode = errorCode;
		this.httpStatus = httpStatus;
		this.retryable = retryable;
		this.retryAfter = retryAfter;
	}

	public static function ok():ClientResult
		return new ClientResult(true);

	public static function failure(type:ErrorType, error:String, ?errorCode:Int, ?httpStatus:Int, ?retryable:Bool):ClientResult
		return new ClientResult(false, type, error, errorCode == null ? 0 : errorCode, httpStatus == null ? 0 : httpStatus,
			retryable == null ? false : retryable);

	public function toString():String
		return successful
			? "ClientResult(ok)"
			: 'ClientResult($type: $error [code=$errorCode, http=$httpStatus, retryable=$retryable])';
}
