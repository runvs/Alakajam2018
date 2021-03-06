package;

import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.text.FlxText.FlxTextAlign;
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
	
	public var input : BasicInput;
	public var id : Int = 0;
	
	public var moveTimer : Float = 0;
	
	public var tx : Int = 0;
	public var ty : Int = 0;
	
	public var moveList : Array<Int> = [];
	public var playerFacing : Int = FlxObject.LEFT;
	
	public var remainingMines : Int = 3;
	public var attackTimer : Float = 0;
	public var attackHoldTimer  : Float = 0;
	public var throwDist : Int = 0;
	public var hasShield:Bool = false;
	public var hasExplodeAll:Bool = false;
	
	private var targetTile : FlxSprite;
	
	private var MaxMineCount : Int = GP.PlayerMineStartCount;
	
	private var invisTimer : Float = GP.PlayerInvisStartTimer;
	private var invisTween : FlxTween = null;
	
	public var playerColor : FlxColor;
	
	public var HudText : DoubleText;
	
	private var pickupSound : VarSound;
	private var throwSound : VarSound;
	var dying:Bool = false;
	
	public function new(i : Int, bi: BasicInput, s: PlayState) 
	{
		super();
		_state = s;
		id = i;
		input = bi;
		
		//this.makeGraphic(Std.int(GP.WorldTileSizeInPixel), Std.int(GP.WorldTileSizeInPixel), FlxColor.WHITE, true);
		this.loadGraphic(AssetPaths.player__png, true, 16, 16);
		this.origin.set();
		this.scale.set(2, 2);
		
		this.animation.add("shoot_p0", [0, 1, 2, 3, 4], 10, false);
		this.animation.add("shoot_p1", [5,6,7,8,9], 10, false);
		this.animation.add("shoot_p2", [10,11,12,13,14], 10, false);	
		this.animation.add("shoot_p3", [15, 16, 17, 18, 19], 10, false);
		
		this.animation.add("idle_p0", [20, 21, 22, 23, 24], 10, true);
		this.animation.add("idle_p1", [25,26,27,28,29], 10, true);
		this.animation.add("idle_p2", [30,31,32,33,34], 10, true);
		this.animation.add("idle_p3", [35,36,37,38,39], 10, true);
		
		this.animation.add("die", [40, 41, 42, 43, 44, 45, 46, 47, 48], 6, false);
		
		origin.set(8, 8);
		offset.set(-6, -6);
		
		targetTile = new FlxSprite();
		//targetTile.makeGraphic(Std.int(GP.WorldTileSizeInPixel), Std.int(GP.WorldTileSizeInPixel));
		targetTile.loadGraphic(AssetPaths.crosshair__png, true, 16, 16);
		targetTile.animation.add("idle", [for (i in 0...10) i], 15);
		targetTile.animation.play("idle");
		targetTile.origin.set();
		targetTile.scale.set(2, 2);
		targetTile.alpha = 0.8;
		
		calcPlayerColor();
		
		CreateHudText();
		
		pickupSound = new VarSound("assets/sounds/");
		pickupSound.volume = 0.5;
		throwSound = new VarSound("assets/sounds/throw/");
		throwSound.volume = 0.5;
		this.animation.play("idle_p" + Std.string(id));
	}
	
	function calcPlayerColor() 
	{
		if (id == 0) playerColor = Palette.colp1;
		if (id == 1) playerColor = Palette.colp2;
		if (id == 2) playerColor = Palette.colp3;
		if (id == 3) playerColor = Palette.colp4;
		
		playerColor.alpha = 20;
	}
	
	
	
	
	public function setTilePosition ( px : Int, py : Int)
	{
		this.setPosition(px * GP.WorldTileSizeInPixel, py * GP.WorldTileSizeInPixel);
		tx = px;
		ty = py;
	}
	
	override public function update(elapsed:Float):Void 
	{
		super.update(elapsed);
		
		if (alive)
		{
			input.update(elapsed);
			
			targetTile.update(elapsed);
			
			HandleInvisibility(elapsed);
			
			//trace(moveList.length);
			
			
			HandleMoveInput();	
			PerformMoves(elapsed);
		
			HandleLayMineInput(elapsed);
			UpdateTargetTile();
		
			HandleDetonateInput();
			
			updateHudText();
		}
	}
	
	function updateHudText() 
	{
		HudText.text = "Mines: " + (MaxMineCount - _state.getMineCountForPlayerX(id)) + " / " + MaxMineCount + "\n";
		if (hasShield)
			HudText.text += "Shield\n";
		if (hasExplodeAll)
			HudText.text += "Mega Detonator\n";
	}
	
	function HandleDetonateInput() 
	{
		if (input.DetonateJustPressed)
		{
			UnHide(0.7);
			
			if (hasExplodeAll)
			{
				hasExplodeAll = false;
				while (_state.getMineCountForPlayerX(id) != 0)
				{
					var m : Mine = _state.getFirstMineForPlayerX(id);
				
					if (m != null && m.mode == 1 )
					{
						m.ExplodeMe();
						
					}
					else
					{
						break;
					}
				}
			}
			else
			{
			
				var m : Mine = _state.getFirstMineForPlayerX(id);
				
				if (m != null && m.mode == 1 )
				{
					m.ExplodeMe();
				}
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
			targetTile.setPosition(GP.WorldTileSizeInPixel * (tx + ox), GP.WorldTileSizeInPixel * (ty + oy));
		}
	}
	
	function HandleLayMineInput(elapsed : Float) 
	{
		if (dying) return;
		attackTimer -= elapsed;
		if (attackTimer > 0)
			return;
		this.animation.play("idle_p" + Std.string(id),false);
		
		if ( input.ShootJustPressed)
		{
			UnHide();
		}
			
		if ( input.ShootPressed)
		{
			
			attackHoldTimer += elapsed;
		}
		
		if (attackHoldTimer > 0)
		{
			throwDist = Std.int(attackHoldTimer / GP.PlayerAttackHoldForDistance) + 1;
			if (throwDist > GP.PlayerMaxThrowDistance)	throwDist = GP.PlayerMaxThrowDistance;
			
			if (input.ShootJustReleased)
			{
				this.animation.play("shoot_p" + Std.string(id),true);
				if (_state.getMineCountForPlayerX(id) >= MaxMineCount )
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
		UnHide();
		var ox : Int = Std.int(MathExtender.objectDir2Point(playerFacing).x) + Std.int(MathExtender.objectDir2Point(playerFacing).x) * throwDist;
		var oy : Int = Std.int(MathExtender.objectDir2Point(playerFacing).y) + Std.int(MathExtender.objectDir2Point(playerFacing).y) * throwDist;

		var tx : Int = tx + ox;
		var ty : Int = ty + oy;
		
		if (_state.level.isTileShootable(tx,ty))
		{	
			var m : Mine = new Mine(this.tx, this.ty, tx, ty, this.id, _state );
			_state.SpawnMine(m);
			throwSound.play();
		}
	}
	
	
	
	function ExecuteCurrentMove() 
	{
		if (moveList.length == 0)
			return;		// nothing to do here
		
		if (moveList[0] == FlxObject.LEFT )
		{
			playerFacing = FlxObject.LEFT;
			if (_state.isTileWalkable(tx-1,ty))
			{
				tx--;
				FlxTween.tween(this, { x : x - GP.WorldTileSizeInPixel }, GP.PlayerMoveTimer, { ease : FlxEase.circInOut } );
				moveTimer = GP.PlayerMoveTimer;
			}
			else
			{
				UnHide(0.4);
			}
			
		}
		else if (moveList[0] == FlxObject.RIGHT )
		{
			playerFacing = FlxObject.RIGHT;
			if (_state.isTileWalkable(tx + 1, ty))
			{
				tx++;
				FlxTween.tween(this, { x : x + GP.WorldTileSizeInPixel }, GP.PlayerMoveTimer, { ease : FlxEase.circInOut } );
				moveTimer = GP.PlayerMoveTimer;
			}
			else
			{
				UnHide(0.4);
			}
		}
		
		if (moveList[0] == FlxObject.UP )
		{
			playerFacing = FlxObject.UP;
			if (_state.isTileWalkable(tx, ty - 1))
			{
				ty--;
				FlxTween.tween(this, { y : y - GP.WorldTileSizeInPixel }, GP.PlayerMoveTimer, { ease : FlxEase.circInOut } );
				moveTimer = GP.PlayerMoveTimer;
			}
			else
			{
				UnHide(0.4);
			}
		}
		else if (moveList[0] == FlxObject.DOWN )
		{
			playerFacing = FlxObject.DOWN;
			if (_state.isTileWalkable(tx, ty + 1))
			{
				ty++;
				FlxTween.tween(this, { y : y + GP.WorldTileSizeInPixel }, GP.PlayerMoveTimer, { ease : FlxEase.circInOut } );
				moveTimer = GP.PlayerMoveTimer;
			}
			else
			{
				UnHide(0.4);
			}
		}
		
		if (_state.level.isTileDetection(tx, ty))
		{
			SmallUnhide();
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
		
		if (playerFacing == FlxObject.RIGHT) angle = 0;
		else if (playerFacing == FlxObject.UP) angle = 90;
		else if (playerFacing == FlxObject.LEFT) angle = 180;
		else if (playerFacing == FlxObject.DOWN) angle = 270;
	}
	
	function HandleInvisibility(elapsed:Float):Void 
	{
		invisTimer -= elapsed;
		if (invisTimer < 0 && invisTimer +elapsed >= 0 )	// just crossed -> fade to dark
		{
			if (invisTween != null)
			{
				invisTween.cancel();
			}
			invisTween = FlxTween.tween(this, { alpha : 0 }, 0.75);
		}
	}
	
	function CreateHudText():Void 
	{
		HudText = new DoubleText(0, 0, 300, "Mines: 2", 24);
		HudText.color = playerColor;
		HudText.color.alpha = 255;
		HudText.back.color = Palette.color15; 
		if (id == 0)
		{
			HudText.setPosition(20, 20);
			HudText.alignment = FlxTextAlign.LEFT;
		}
		else if (id == 1)
		{
			HudText.setPosition(704, 618);
			HudText.alignment = FlxTextAlign.RIGHT;
		}
		else if (id == 2)
		{
			HudText.setPosition(704, 20);
			HudText.alignment = FlxTextAlign.RIGHT;
			
		}
		else if (id == 3)
		{
			HudText.setPosition(20, 618);
			HudText.alignment = FlxTextAlign.LEFT;
		}
	}
	
	public function UnHide(t: Float = 1 ) : Void
	{
		if (invisTween != null)
		{
			invisTween.cancel();
		}
		invisTween = FlxTween.tween(this, { alpha : ((t < 0)?  t: 1 ) }, 0.25 * t);
		invisTimer = t;
		
		LocalScreenFlash.addFlash(x + GP.WorldTileSizeInPixel/2, y+ GP.WorldTileSizeInPixel/2, 0.5*t, playerColor);
	}
	
	public function SmallUnhide() : Void 
	{
		if (invisTween != null)
			invisTween.cancel();
		invisTween = FlxTween.tween(this, { alpha :  0.2 }, 0.2);
		invisTimer = 0.3;
		
		//var c : FlxColor = playerColor;
		//c.alpha = 5;
		//LocalScreenFlash.addFlash(x + GP.WorldTileSizeInPixel/2, y+ GP.WorldTileSizeInPixel/2, 0.35, c);
	}
	
	
	override public function draw():Void 
	{
		super.draw();
		
		if (throwDist != 0)
			targetTile.draw();
	}
	
	
	public function KillMe()
	{
		if (hasShield)
		{
			hasShield = false;
			UnHide(0.5);
		}
		else
		{
			dying = true;
			alive = false;
			UnHide(5);
			animation.play("die", true );
			
		}
	}
	
	public function pickUpPowerUp (puType : Int)
	{
		pickupSound.play();
		UnHide(1.0);
		if (puType == 0)
		{
			hasShield = true;
		}
		else if (puType == 1)
		{
			MaxMineCount++;
		}
		else if (puType == 2)
		{
			hasExplodeAll = true;
		}
	}
}