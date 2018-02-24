package;

import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

/**
 * ...
 * @author 
 */
class Player extends FlxSprite
{
	private var _state : PlayState;
	
	private var input : BasicInput;
	public var id : Int = 0;
	
	public var moveTimer : Float = 0;
	
	public var posX : Int = 0;
	public var posY : Int = 0;
	
	public var moveList : Array<Int> = [];
	public var playerFacing : Int = FlxObject.LEFT;
	
	public var remainingMines : Int = 3;
	public var attackTimer : Float = 0;
	public var attackHoldTimer  : Float = 0;
	public var throwDist : Int = 0;
	
	private var targetTile : FlxSprite;
	
	private var MaxMineCount : Int = GP.PlayerMineStartCount;
	
	public function new(i : Int, bi: BasicInput, s: PlayState) 
	{
		super();
		_state = s;
		id = i;
		input = bi;
		
		this.makeGraphic(Std.int(GP.WorldTileSizeInPixel), Std.int(GP.WorldTileSizeInPixel), FlxColor.WHITE, true);
		
		targetTile = new FlxSprite();
		targetTile.makeGraphic(Std.int(GP.WorldTileSizeInPixel), Std.int(GP.WorldTileSizeInPixel));
		targetTile.alpha = 0.4;
		targetTile.color = FlxColor.CYAN;
	}
	
	
	public function setTilePosition ( px : Int, py : Int)
	{
		this.setPosition(px * GP.WorldTileSizeInPixel, py * GP.WorldTileSizeInPixel);
		posX = px;
		posY = py;
	}
	
	override public function update(elapsed:Float):Void 
	{
		super.update(elapsed);
		input.update(elapsed);
		
		//trace(moveList.length);
		
		
		HandleMoveInput();	
		PerformMoves(elapsed);
	
		HandleLayMineInput(elapsed);
		UpdateTargetTile();
	
		HandleDetonateInput();
	}
	
	function HandleDetonateInput() 
	{
		if (input.DetonateJustPressed)
		{
			var m : Mine = _state.getFirstMineForPlayerX(id);
			
			if (m != null && m.mode == 1 )
			{
				m.ExplodeMe();
			}
			
		}
	}
	
	function UpdateTargetTile() 
	{
		if (attackHoldTimer <= 0)
			targetTile.setPosition( -500, -500);
		else
		{
			var ox : Float = MathExtender.objectDir2Point(playerFacing).x + MathExtender.objectDir2Point(playerFacing).x * throwDist;
			var oy : Float = MathExtender.objectDir2Point(playerFacing).y + MathExtender.objectDir2Point(playerFacing).y * throwDist;
			targetTile.setPosition(GP.WorldTileSizeInPixel * (posX + ox), GP.WorldTileSizeInPixel * (posY + oy));
		}
	}
	
	function HandleLayMineInput(elapsed : Float) 
	{
		attackTimer -= elapsed;
		if (attackTimer > 0)
			return;
		
		
			
		if ( input.ShootPressed)
			attackHoldTimer += elapsed;
		
		if (attackHoldTimer > 0)
		{
			throwDist = Std.int(attackHoldTimer / GP.PlayerAttackHoldForDistance) + 1;
			if (throwDist > GP.PlayerMaxThrowDistance)	throwDist = GP.PlayerMaxThrowDistance;
			
			if (input.ShootJustReleased)
			{
				if (_state.getMineCountForPlayerX(id) >= MaxMineCount)
				{	
					// todo dead man's click
					
				}
				else
				{
					ThrowMine();
					
				}
				attackHoldTimer = 0;
				attackTimer = 0.2;
				throwDist = 0;
			}
		}
		else
		{
			throwDist = 0;
		}
			
		
	}
	
	function ThrowMine() 
	{
		var ox : Int = Std.int(MathExtender.objectDir2Point(playerFacing).x) + Std.int(MathExtender.objectDir2Point(playerFacing).x) * throwDist;
		var oy : Int = Std.int(MathExtender.objectDir2Point(playerFacing).y) + Std.int(MathExtender.objectDir2Point(playerFacing).y) * throwDist;

		var m : Mine = new Mine(posX, posY, posX + ox, posY + oy, this.id, _state );
		
		
		_state.SpawnMine(m);
	}
	
	
	
	function ExecuteCurrentMove() 
	{
		if (moveList.length == 0)
			return;		// nothing to do here
		
		if (moveList[0] == FlxObject.LEFT && _state.isTileFree(posX-1,posY))
		{
			trace("left--");
			posX--;
			FlxTween.tween(this, { x : x - GP.WorldTileSizeInPixel }, GP.PlayerMoveTimer, { ease : FlxEase.circInOut } );
			moveTimer = GP.PlayerMoveTimer;
			playerFacing = FlxObject.LEFT;
		}
		else if (moveList[0] == FlxObject.RIGHT && _state.isTileFree(posX+1,posY))
		{
			posX++;
			FlxTween.tween(this, { x : x + GP.WorldTileSizeInPixel }, GP.PlayerMoveTimer, { ease : FlxEase.circInOut } );
			moveTimer = GP.PlayerMoveTimer;
			playerFacing = FlxObject.RIGHT;
		}
		
		if (moveList[0] == FlxObject.UP && _state.isTileFree(posX,posY-1))
		{
			posY--;
			FlxTween.tween(this, { y : y - GP.WorldTileSizeInPixel }, GP.PlayerMoveTimer, { ease : FlxEase.circInOut } );
			moveTimer = GP.PlayerMoveTimer;
			playerFacing = FlxObject.UP;
		}
		else if (moveList[0] == FlxObject.DOWN && _state.isTileFree(posX,posY+1))
		{
			posY++;
			FlxTween.tween(this, { y : y + GP.WorldTileSizeInPixel }, GP.PlayerMoveTimer, { ease : FlxEase.circInOut } );
			moveTimer = GP.PlayerMoveTimer;
			playerFacing = FlxObject.DOWN;
		}
		
		moveList.remove(moveList[0]);
	}
	
	function HandleMoveInput():Void 
	{
		if (input.LeftJustPressed)
			moveList.push(FlxObject.LEFT);
		else if (input.RightJustPressed)
			moveList.push(FlxObject.RIGHT);
			
		if (input.UpJustPressed)
			moveList.push(FlxObject.UP);
		else if (input.DownJustPressed)
			moveList.push(FlxObject.DOWN);
	
	}
	
	function PerformMoves(elapsed : Float):Void 
	{
		moveTimer -= elapsed;
		if (moveTimer <= 0)
		{
			ExecuteCurrentMove();
		}
	}
	
	
	
	override public function draw():Void 
	{
		super.draw();
		
		if (throwDist != 0)
			targetTile.draw();
	}
	
	
	public function KillMe()
	{
		alive = true;
	}
}