package scoreoid;
import flash.events.Event;
import flash.net.URLLoader;
import flash.net.URLRequest;
import fsignal.Signal1;
import haxe.Json;

/**
 * ...
 * @author Andreas Rønning
 */


private class Score {
	public var name:String;
	public var score:Int;
	public inline function new(name:String, score:Int) {
		this.name = name;
		this.score = score;
	}
	public function toString():String 
	{
		return "[Score name=" + name + " score=" + score + "]";
	}
}
private enum ResultType {
	GET;
	POST;
}
class ScoreResult {
	public var type:ResultType;
	public var rawData:Dynamic;
	public var scores:Array<Score>;
	public function new(type:ResultType, ?data:Dynamic) {
		if(type==GET && data!=null){
			rawData = data;
			scores = [];
			var itemArray:Array<Dynamic> = cast data;
			for (item in itemArray) {
				scores.push(new Score(item.Player.username, item.Score.score));
			}
		}else {
		}
	}
	public function getHighest():Score {
		if (scores == null || scores.length == 0) return new Score("N/A", 0);
		return scores[0];
	}
	public function toString():String 
	{
		return "[ScoreResult scores=" + scores + "]";
	}
}

private interface IRequest {
	public var responder:Signal1<ScoreResult>;
	public var id:Int;
	public function onResult(e:Event):Void;
}
private class ScorePost implements IRequest {
	public var responder:Signal1<ScoreResult>;
	public var id:Int;
	public function new(id:Int, responder:Signal1<ScoreResult>) {
		this.id = id;
		this.responder = responder;
	}
	public function onResult(e:Event):Void {
		var ldr:URLLoader = cast e.currentTarget;
		ldr.removeEventListener(Event.COMPLETE, onResult);
		responder.dispatch(new ScoreResult(POST));
		Scoreoid.requests.remove(id);
	}
}
private class ScoreRequest implements IRequest{
	public var responder:Signal1<ScoreResult>;
	public var id:Int;
	public function new(id:Int, responder:Signal1<ScoreResult>) {
		this.id = id;
		this.responder = responder;
	}
	public function onResult(e:Event):Void {
		var ldr:URLLoader = cast e.currentTarget;
		ldr.removeEventListener(Event.COMPLETE, onResult);
		var obj = Json.parse(ldr.data);
		responder.dispatch(Scoreoid.lastResult = new ScoreResult(GET, obj));
		Scoreoid.requests.remove(id);
	}
}

@:allow(scoreoid.ScoreRequest)
@:allow(scoreoid.ScorePost)
class Scoreoid
{
	static var key:String;
	static var id:String;
	static var requests = new Map<Int, IRequest>();
	static var requestID:Int = 0;
	public static var lastResult:ScoreResult = new ScoreResult(GET);

	public static function init(key:String, gameID:String):Void {
		Scoreoid.key = key;
		Scoreoid.id = gameID;
	}
	static function nextID() {
		requestID++;
		if (requestID > 30) requestID = 0;
	}
	public static function getScores():Signal1<ScoreResult> {
		var reqStr = "http://api.scoreoid.com/v1/getScores?api_key=" + key + "&game_id=" + id +"&response=json&order_by=desc";
		var req = new URLRequest(reqStr);
		var sig = new Signal1<ScoreResult>();
		var urlldr = new URLLoader();
		var reqObj = new ScoreRequest(requestID, sig);
		requests.set(requestID, reqObj);
		urlldr.addEventListener(Event.COMPLETE, reqObj.onResult);
		urlldr.load(req);
		nextID();
		return sig;
	}
	public static function postScore(name:String,score:Int, sync:Bool = true):Signal1<ScoreResult> {
		var reqStr = "http://api.scoreoid.com/v1/createScore?api_key=" + key + "&game_id=" + id +"&response=json&score=" + score+"&username=" + name;
		var req = new URLRequest(reqStr);
		var sig = new Signal1<ScoreResult>();
		var urlldr = new URLLoader();
		var reqObj = new ScorePost(requestID, sig);
		requests.set(requestID, reqObj);
		urlldr.addEventListener(Event.COMPLETE, reqObj.onResult);
		urlldr.load(req);
		nextID();
		if (sync) {
			var s2 = new Signal1<ScoreResult>();
			sig.addOnce(function(e) { getScores().addOnce(s2.dispatch); } );
			return s2;
		}
		return sig;
	}
}