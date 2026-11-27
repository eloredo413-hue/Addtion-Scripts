-- 1988 GUI (Easter egg): the E Sprites Player Script (All-In-One Retro Suite), a joke recreation of those fake old-school
-- Roblox videos: pixel-art sprite players, MS-DOS HUD, 8-bit sounds, DOS world textures. Press E to switch it off and on.
-- Cleanly ordered top-to-bottom so all functions/locals are in scope.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

if _G.ESpritesCleanup then
	pcall(_G.ESpritesCleanup)
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local CONFIG = {
	Sheets = {
		Head = {
			AssetId = "rbxassetid://95610366391139",
			CustomFile = "pixilart-sprite (2).png",
			Frames = 5,
		},
		Torso = {
			AssetId = "rbxassetid://73822667722804",
			CustomFile = "pixilart-sprite (1).png",
			Frames = 2,
		},
		Legs = {
			AssetId = "rbxassetid://133356353870349",
			CustomFile = "pixil-frame-0 (1).png",
			Frames = 1,
		},
		SideLeg = {
			AssetId = "rbxassetid://85266574510905",
			CustomFile = "side-leg.png",
			Frames = 1,
		},
		Arms = {
			AssetId = "rbxassetid://108847145521235",
			CustomFile = "pixilart-sprite (3).png",
			Frames = 4,
		},
	},
	ApplyToAllPlayers = true,
	TintOtherPlayers = true,
	TintLocalPlayer = false,
	EnableToggle = true,
	ToggleKey = Enum.KeyCode.E,
	BillboardWidth = 5.5,
	BillboardHeight = 6.5,
	StudsOffset = Vector3.new(0, 0.45, 0),
	TopViewBillboardSize = 7.5,
	TopViewWorldOffset = Vector3.new(0, -0.55, 0),
	TopViewEnterThreshold = -0.82,
	TopViewExitThreshold = -0.76,
	AnimFPS = 6,
	ChoppyZoom = true,
	ZoomStepStuds = 3,
	EnableFirstPersonViewmodel = true,
	FirstPersonArmSide = "Right",
	EnablePixelAudio = true,
	PixelateSurfaceImages = true,
	ReplaceExplosions = true,
	ExplosionAssetId = "rbxassetid://0",
	ExplosionCustomFile = "e_explosion_sheet.png",
	ExplosionFPS = 16,
	EnableDOSWorldTextures = true,
	ApplyDOSMaterials = true,
	ApplyDOSSurfaces = true,
	DOSSurfaceTileStuds = 2,
	DOSMaterialTileStuds = 4,
	RemoveAllShadowsAndLights = true,
	ShowPixelNameAndHealth = true,
	EnablePixelChatBubbles = true,
	ChatBubbleDuration = 7,
	MaxChatBubbles = 3,
	EnableRetroHUD = true,
	EnablePosterization = true,
	EnableRetroSkybox = true,
	ReplaceParticles = true,
}

local HEAD_FRAMES = { FRONT = 0, BACK = 1, LEFT = 2, RIGHT = 3, TOP = 4 }
local TORSO_FRAMES = { NORMAL = 0, TOP = 1 }
local ARM_FRAMES = { IDLE = 0, SIDE_A = 1, SIDE_B = 2, TOP = 3 }

-- ============================================================================
-- SHARED STATE
-- ============================================================================
local enabled = true
local inTopView = false
local connections = {}
local playerRigs = {}
local playerConns = {}
local CAMERA_BIND_NAME = "ESpritesRetroCamera"
local pushPixelChatBubble
local HAT_SHEETS = {
	Cap = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAABaElEQVR42u1aQRKDMAiETt/jr3yVL/KaD9GTM9Zpx5gACcnujLcWV2Sz0MIEAERiFJejJ+aN2gCIiFJKqvGWZRkiL5oCkSCnR288o+Qtmguq5PGFvAJAnYOIkqK9+lQx+Dw7ccn5zmwO07T+cpItIjYzHDObCESTbyXHnrhEHdK7rT9xvjRectaVUrLm+Dh2AScLkUgtWrxPy/p73UjX5VK0juz7WXMsie+dr+sprRH7FEe83qdl/WFIB0xaGC2RRBjSAeDo168CGB5wELiHZfDwLgKBAABaLEDJDaYDHGT60YItgxMF/2MTDgIM8aOBlQNeBSI1JGpd/Hzrf5xKkha1PbjJv9YqDzOz+rDu4R7btmV9bl1XPQfRXnt+il9r0jWcoq9dOz07M7NoHCYnUQ+xM4YWC/gq6EMoT8RycbqhlilDCGTf92mrtsGz86nwW21k93VqlPT7jryk43zVzgc9ce4N0kOePuCOQiGgtorZAAAAAElFTkSuQmCC",
	TopHat = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAABNUlEQVR42u2aS66DMAwAzVNPxHGy8tG8yiG4XLrpkyq1iaGkYNKZJR/JWB5sSEQAoMpECsCh/HINTZ2SdLagxPclIcysebGqHh7TkflbLYiXqK08EtutAImvTxHujfNJmK6xnZW/GxMEeAX4pktUu8v/MVUtI4xfCAKuHCml6rnavWY2hCR/1AdyfCKHiEhKqdpdnrpJQRAYDk+OtZJcHQShe3wsxxpJrt5FEAQAQQAQBKA7q3/zzvMc+kGIbzOTqpbaWsaW75Ccs7S+Z6TDr95lWeggEAczk5zzLjkYseDqTN46RksST44vbIeJO2LB0JIUZ0W8em5kOd49QAkaF/H1ia9FhM2K4fL3IsjZ86Tz5iG+ffFtLtKDt7uHyx8jFjQL/LHhsHe3YsRixLrciBWBcPm7A6uxmkTiqOY4AAAAAElFTkSuQmCC",
	Crown = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAABWElEQVR42u2aKxLCMBCGCYPDcggUAsNJQPSACDC9BgaB4hBY9GJgBmhTunk1od9nOsNsyT+Z7LMxExgrkng9U+ImTTknAH/m1eCfMUS2aQ+aORZ59sggAMoMIkpPF4c1Qq6Hvm57acsYLRE9bvqyr591JpkRI6CwAYLxDDCa//5wEFukEU1kaqk9Ve/Hth+xvo/IXVVV4h5kr+p97pdl47f56trbVmtvs6UHAQhUYvnOzWPP3dEHwSGDAPhkkEbNuHs+D8rphfI91+kI+mCoEgsgBySyvaeDuEawVJEPfX9B3wnUfHW12rrYk0GgCGyjW1e7X/Y2p2k4SF1XA29N9xde9Pnpe/U0r+8Syeoiz7tf59MtqJ71ZtHLjikWQAcmVDMTWRv6AuvL/DavfJdCsTPIs8Qy9CBQJH1LotDgIOOsFt7vbA2V0SixKLGy0jcZWK/GQSSXPXsAfxCnhM3+aToAAAAASUVORK5CYII=",
	Beanie = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAABN0lEQVR42u2bUQ6DIBBEXeN5vP85uBD9sYmSLoosdcH3kn40JmbcMOxOpdMEACpidJ/Y+P7o86WrF53VuhYzhfGoUURc7QToK19sqSbVHSLxabO0qt8yAeyMcdUU2uLcmUVGKIoYtNenxj302YwTt41x0lVMdD1dv/lsZ/jHp6atoq9qHUWDe2SfvWah/3rWEIJah9y13PUcM5PFe0eqFsZQxq/Ya5HIIFAyLmWD8YhgELrHJUIIh+/ruhZ1kS28dxfcGbEAMAgABgEgg4BV7paiHFKSOZSQLxgERk30791JtJo404M+W327td9W6s3u4aZ+agdJf9ZrTWkLR5/JCCTfs1Pejpp4qR8jFsi2oE2MYnAGiwwC/o1SYpbkTbuMVBQMAuocnvzPwzL7ENIJ6V2EdK+4qd8HNeer9fabVegAAAAASUVORK5CYII=",
	Propeller = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAAByUlEQVR42u1bO3aDMBAUeXRcg4KKIk3O4RtQ+FgU3CDncOMilQqu4VpuAo8QfVZIoN/Me24stB5WO9pdgRkDAECJinCNiIAD+J3HL3YE9V9NsTBN0ynMhmHwYgf8ggfnqSIN6T9kEPDT8n39dNqLm55fyifGDFIdvJGrUj/4eQzE7j6vX/CxJU3czRGe+Qf1X80AgDGxDXIXLHZ+hZJ8f/RhUKTNx/d8m50vRn5X+S8acUiEcsW6nrq+NTV1ysDHllSjzp3+mpZzL7uWC9em50o71FKDysuFiw9etuKQ9Bmk/qS7z06ZJIb4Q4lVcFlFEdkijn2QtZyvYwShJltuQSAFg3p8qjoOdZ2feg8CAMUDGaRguO7sKWcGCAQwoTI16UsT3PRc2sguYyYbLOHjXgikcJHwsTWeZJlOinIVB3oQYBGJd6M5iAMZBPiTSRijPVMiCCMLcagEIiQ3q4TqIdIWxAeBpnd4BGFRrLgeLR18Q+ZDi11daHoM255k+y7VEVFkIwxtBvn8/gpC5nl7aMd98nreHv8C03epobO3/23f9+bYvK/io2yALOP/pJReYlWR2BYF+ifZABGRLorIOAAEgjt4HEr99QYs3RScv9AqKgAAAABJRU5ErkJggg==",
	Cowboy = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAABJElEQVR42u2bLRLCMBBGEwaP4QY1aAyaIyAwKE6AhhOA5gQoDIIjoDFoTG+A4QTBMB0mw/Rvm+mmfU/UdfLaafbLpq010BecMh8bw00b8NwAyGaxU+CAX30/Z4wxp1Wi6sFbn9MokoQEAchhKK08P5XgLyXOdzUrCX41/IrGC422JJNMEICubzDY4BNEe0XAT8e40uTaLyeN+uwuT3oQgOBLrEf6Vn0B+LVb+WPrKapCggAUJEhuA3S8v1Q3YviFbWS7nhAkCEATPchmNlYl5lde/NQmV7+bdAANlN2WDTZBpslI1x3xKiB+Mj+ftt+okyAA1XDKxrTZoUVBUySIn9gvlq953XU7V+G2ONwyL3axAFhi9Rr7rdj8USiUZAmDH36e3we5BWxcRcNxSQAAAABJRU5ErkJggg==",
	Viking = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAABbElEQVR42u2aMXKEMAxFrcyejd4FDRVHo6KhoOdyTpFkZ3HWIIyxvcN7HQOMPx6kLwnEwN1whdeXT9qsL94XgO1odpVFuFNoRl8ih5jn+VIx1tqPdhQcBEDjIM79JB4RKRXZIR0Gfen0PcX9nr/aQXwneaNDdlxPcuxbaO0HOQKqmBy4/++pH+Ql1n6ELhYR50Vw6umHvMt82odBX5y+o0zTdOr+tm2z9FRd162Ox3FM8vw4CFTNMAyq65Zlibqv7/vdAJHXjPeXifxMmLpWtda6rdrYrz3RF63PEWbxMMUCODghWGWc3FMOxdQCfcf0bTpNLVOsUKMcW2I1TaMusTaadMFBAA426ava9ewU40LXQ98RUVLmg7X/Jb2UjpQBAnCbAN5bezdAEsyxVcTOrdG3q0+2eiTFv1I5+l7R9HOZNRljmGIBnCuxCmSYUzUu+uKzJeAgAAQIQA67dRVqQt+9Sij1Hp78WTG4Z98LoMjTEwWGzQAAAABJRU5ErkJggg==",
	Mohawk = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAAAnklEQVR42u3bSwqAIBQFUI222CpdpI2DsA/5Sc6ZNvBG3SdBxgBl+eJ6nPnmF88f6rQ/N1zryxyhce7R8xVz520rL55Sr52kyftnB4GCtdZkOZk0+eNJ8yrH4/H8Pvfo+X79TdTq/bODgIKAgoCCgIKAgoCCgIKAgoCCAAoCN60/zh5DOPxjU3WdCfNhB4F+02eU8yDUNeqJQudBoLcdqVok1hql5O4AAAAASUVORK5CYII=",
	Halo = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAAAw0lEQVR42u3aYQ7CMAhA4dZ4RU+5Q9a/atRkNG3H9r0LQAjlwbJacFXa5Hg1Y5Fu+gQ42atGvzFae8xttLql7D0GARiEOT6N8WWij03id/xD9yCDAH+4791dD2gx+cVugamTu9atBW+fpfVjECBokOiLD02WwESTX19+KW+n2fVjEKBzf7Xj587vbRIv/HoUzcMNAmS8QVZNmtkT/ur5FfVjEGCYQXAiXm6AtiJuNhgEsB+j+JuXQQAGwRCj6DUGAXbzBH9FQCozMVPzAAAAAElFTkSuQmCC",
	Beret = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAAA60lEQVR42u2bSxKEMAgFh6m5/1lyQ9zOQmP+QNK9V58W8AKJ8oFT0cXPk4gf6UucAGyW1dDvGKprDUREQsYeDgIw2EHU4Jnoa9enFo5R4SiunQQHAcjwq610vZVIRHRkZUTfHOe76RnyLzveoawsT0oTBMB2qmA/SLhNkKlr1qf7/lXGt9KFvj59RUFSq7/1Ou/QgwA09iBw8LLGQQ+CgwCEdZCUkmvh6NurQcZBAAKSW2h6P+2JvjJ9UXfS1WjMyz4IBKrgMvckylsS4iDn6It2mpeddICCQNWVCdFbFWEfovxRaJogTLEAMlzyEGhNhazfrQAAAABJRU5ErkJggg==",
	PartyHat = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAABcElEQVR42u2ZIRLCMBBFd5k6DIJDoDgJlgoUgkP0CD0BCoFCBNuToDgGBh0EbaFMYZpmIWH7n6Mi/RNm920aJjnsy2+muEA+vdg3z733MMHeAg1cT7PG7/H8LLJuIlW91i6bpctHG0knRD6ZbtwVVeaDQYAKpIwhWSD3zresOp+JrZEgXy+T+QmEmUOYj4nIbqdTWm32REQ0yRciC4/Qe4CGQ/olKyIdsYyJe+uQT8Ycadopd7VOIJPUXLKCJvnC+r4fBgFq7VE+95oZ+xjkc8cpO03AToJ8klTmMO+emyiLQwoYBKjG1yLyn3kx8+vON4CDOQwCBlUcPhZxmWtbb3w7v4iPfd5JyPf1fKJfsR55+Zv72Vogh926vgdpo7wbccoDgwCMVj89g4B/g8uO/9kkHc9GIczhMmq53o3AIGBQuJ5HYBDQahLfdf59tIJBwGDPHS4WcTbI09eUONsg8omYBLhvho38D0A+pfYIWQM3CbOzYF2FhnoAAAAASUVORK5CYII=",
	Headphones = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAAA+0lEQVR42u2aSw7DIAxEQ8UpWXG0rLimu+oiaZEQ5TOB95ZVGjvSWMw4OQ4AyOIyv5tYPzXYxNor9DcTGf353JUhhKGdpZSa37P0GXrUXqG/majo78UhCpDH5461z0T1nuTb5NqmlgJE9XexWOd5Xv4cYxxyvP+qC0M8vVOqr6g/LxAODf1uF4aVlhNWarGAIDw0AD8BQjoAAwLwn78zUQ/oGt9P3vN26s9ELZa8/pbMIPetRCmjtmfq/cEmIb1UULWCXb0/YIu1NTt+wsKAgFLeapW7GBBYYhBU61fDmheAAQHAYn2hvv1hO/Ucb8qLQo3nXdrPD9RAs9pvueFYs1i/jN8AAAAASUVORK5CYII=",
	Sombrero = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAABHUlEQVR42u2aLRLCMBBGNwyuF0FVYFAcAlEO2QjOgUGgajgGOhj+BDO06SbdTN7zTbeZ7Lf7beMEaiEYi8eVsGkrzg2AbhaHBd5JfPHxBRGREDpbB8/5IirJGo2AylpFlypBVJTIOR8SKQfxjeG48PHu5y9xv26inmvaAQ8CkLvF+q18U5XoqRyvdRSVmvhiKpH3efuirisyQaggAH8qyCjT8zV10LZGKvN54otU9sTTrdnfTQUBKMCDGJ6TE1+Fyl2SSQcww/a0k/0t/tnL4ZwoQbTn573yesRHpcGDAGRuVcXeLU9IwNsjGfmTXkrlwoPA4sReHUlN0w4kSHX0bAEeBECxxXJsQwVm83N3y5L/FesemOSoyKeTINN5AOtEYGY11IesAAAAAElFTkSuQmCC",
	ChefHat = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAABEUlEQVR42u2aSw6DMAxE44rrcBeOyl04kLuqRKsqOJ/GDn1vjcQoij0zpZLg31Dn98tMh/XgvgDUTbMG0oK+dn2aUkqqvgYiIkV6vc9vYUdA2Cw4aJhPQ2saEJdNIyIaeRNOrM+kZ9/3rnq2bcte+oLzpIMAzNBBomdU9NXpy+rq7RxWJzF0ER0csQQHAShk+XSTVzZ0yNBXGwV9bfqADgLwuw6SPDJ1w+ZDnzHLW3SM+hWLDgJw0w4yZLP0Bn22lHDVja42vocj5z7ghRkQgCDxv1vkykUqBuTPL9zpC3bE3mvmOI6i59d1rXoPHQSgcpr5t+y99c3GW8RqcZCSiIWDAOAg6Lubg1DSAb5f7KE8AeUphGX2uskVAAAAAElFTkSuQmCC",
	Ushanka = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAABKklEQVR42u2aOxLCIBRFH056d2Bt415C4WJcgYuxSPZiY+0OXAE2MhMzZsbwh5zTAzcM714gKIGtYTKPr2qarB3rBcCvmk0BGtDnr8+IiAzDkHXBaa2rSpIOjwC2gssF2+V2HK21cXQU9PnpExGRvu+j6hvH0bnt9XxMUhmX24MzCECoLdZP5wvtNNZZ7DgrnPAvZ16rd8npGtQHKyBBACgQAAoEIMkZ5At7bx3rNmbef6i9tM/tSQpK0Vf6PJEgADUnyMTpQ9+OmFlyiEtyTNo5tV/SZfFNzoL0qVlC54K3WACbSxBohur+k9yfryj9ng57EgQgtJuYRM7jOo5x+KYQulrRVwvGvsWKnSCft1iKBAEIcAZJ5UAqcbtU/ZeuD5hsaGGLVUItvAHCf2pm380DCgAAAABJRU5ErkJggg==",
	Wizard = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAABzElEQVR42u2bMRKCMBBFdzNcgp7C3pYjeAwrCw9jQcUxPIKtPYW9x4gNzIBjIAnZZBN3Z6gUeP7s32wCAoQPDbxDC1vREVRDFRrucH5xHmjOfBzZtOVRrIYVARwwNwfrOJxfMPSNBgBMXX3rtrM66f24fCckljK+SAU49E0qoXLkS8mmXQ1hYZgUZiHRECndyygJOfOlZNM2pvhKeKcZZjwXc9WwooKT1op1q6W3EnxuCpN+YwKumqVuu3kLhrmNL4aCe15Piw+OtzuHKi18HrPG+3EB16Qb+gZsrkvZ1q+Y2PueijoDmO9qpeRjObP5mGPS0dSK5Ty+qrQBzr21Ijaw3mqrTJo9r6fF4WOS8d46p/FVMeASVGnhKzui6VeFgpt65kSLTuETc5Dop2L+MlmPlNH2/VO7irEHmHjXSPgI1yE2bBZbx5iTfiomHHGVFr4AUbfd4vlGKHPkqh/GhCOs1MLnyDOZYaPaz5PKxAAO18Lc9KtA4h8Dx8TVa0/AfxnB9B3Ctiq9UPOqwpRN+Pbzrc4mtglvE54vK7LUD20XbzHDUHWEbx+fc5I6vO7ua072+kmLJWFM7B//89g7W0mLJS1Wdi0Wl2Cp3wda0m/kod4dkwAAAABJRU5ErkJggg==",
	Fedora = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAABSElEQVR42u2aOxKDIBBAIZMjeIQUOROVdQ6U2oozWeQI3oE0kkmciCCiIO+Vjp+dnX2yfIQAgFkkKQAHpvY6QhCYFUIp5fWQ1vq0dYUgYEKFCBRGnl0Qk7mkxBcR25IUf0YHETLKjM/LUvMnt0hi5J8mugCJb13RueKyYnRd53xR27bC911rYz0yf1c6jPpaqi3EsNj7XKLYa1prU1rLhSDwI4evGC5RUv3xj+BCWTB6xMoxFWVu3jJ+2yAIACMIAIIAVM3iisLrfk/aM976PmpVg/iC40s6D3FN0tcsSz+bJmn+HsPAMi/4oZT6LNeGiuKzH1IiCFJh1zDuRzj3LHxF2WGjMJsWy2QcG/ElaJ9FXkdNssyfDEnWXswklfji4lsszIMPK2aZP1oskF+FwXF35iDg25ZNhYls54pPCD1+fXOQnMgyf29vFKgGlWlrJAAAAABJRU5ErkJggg==",
	Bandana = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAAAzklEQVR42u3ZsRGCQBAFUHEsgQ40gNYsyNYg0A7oQWOckWOE0+V4LzNgXJb7cCyHAwB8o9KC3Xpaa2kn62S/7k3zk/+59P1me3S0TEBAQEBAQEBAQEAgvKkxb/Q5ufqW1RddiP5NfgeJPidX37L6opvbv0/nv/T4ZEBI3tGqP93teHOr69Hv6zBk32KNnLtu1RN6tG1RFyDXBcJLOggIbNHsLdbWtkRrS22ZbKl2HhAmx6jVzJf6UEqdfgkIuQNf3BM+R5N8iCu7vuhC9O8FWOkz/Q+lPqcAAAAASUVORK5CYII=",
	Hardhat = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAABRElEQVR42u2asRHCMAxFZS4dLUNQsQHjMBXjsAEVQ9BSiybcmVwwxEjGNu91HGdZlv+PfYlEAAAAcghGcdQ5PvwGLayj6hisAp2Om6ff+8MVeTVuitt5KyIi691ldn+j/7VXswwGTw8xihGc45c+bWvO7WW+D9EvIR4TmSUU1I5bDYdPF55ivbu4jF+6OV7k5ldzblMxWuU6OVWCRaxf1nDFjYIrlYcQx5jaenEwCOZwC96DSTAI5nCldZNgEAAMAoBBADAImBGMXhEnGecIGAQwSWfmEDFsNaG1pGmTmL/R6sEccwbRmUV+W6RPedfPo7lzlPoi6/QEXlq7VA2TJrGoVZRzFz1ZQ21iSokiJ7cS92xPCq45jGN16dyT+f6mWRH+9MoVCV9TV+jeTgsMAtlmoQCJe34lG6ONiUUR91dU0e5+B4ntdJCK+a65AAAAAElFTkSuQmCC",
	Knight = "iVBORw0KGgoAAAANSUhEUgAAAMgAAAAUCAYAAADIpHLKAAAA8klEQVR42u3bsQ2EMAyF4cfp5qFgCIZIldFSMQRDULAQtHcSQUKOIcD/lSki506OY1k0khYBNxZC2FwfhsG8dyNpSSmp67qqDj1Nk2KMkiTis8dnEWPUPM9/a23bFtm3RHzjOG6u931vju/D/QPkkSDAju9vSa4Z8YEKAtRaQbaap7PlmjVLPNYG8GpX/RegggAkCECCAGf2IEff7bl3stf7/+59hddZ6VeoIMD1FSQ3upfs43uvvff2LRX7WZ50FioI8LYK4nk7ee39pBuV6kAFAUgQgAQB3taDHOU9l3jT3KPk78RcxK4Rn9zi5jw/uV0BE+lYVaG5sQ4AAAAASUVORK5CYII=",
}
local COS_SHADES_B64 = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAMCAYAAACqTLVoAAAAwElEQVR42u1YOw6AIAy1xFP4WXTm7k7Gy+ji5xo6SSIxESkUlL5JSV77akspQsYIjT2kc0AKgUBcXXvyicQUgBJeVI0xcVumyzsV947vqIDQCQwUBwpCX1jnMRv6zsoYlrvO4+/7fWxxirtFKaW1QQyXQY9cP4vLulWVej6b4iUX69dmBjBt815sv/wuJLOKeEqmgViw5GL8fhIxxia4CfIRkBLgQ9dK7gAM2h3BP4IcDleeupRzncB7ILrCIS2AA3n0QrwPXDQLAAAAAElFTkSuQmCC"
local HAT_STYLES = { "Cap", "TopHat", "Crown", "Beanie", "Propeller", "Cowboy", "Viking", "Mohawk", "Halo", "Beret", "PartyHat", "Headphones", "Sombrero", "ChefHat", "Ushanka", "Knight", "Wizard", "Fedora", "Bandana", "Hardhat" }
local HAT_META = {
	Headphones = { fPos = UDim2.fromScale(0.531, 0.46), fSize = UDim2.fromScale(0.76, 0.35), sPos = UDim2.fromScale(0.531, 0.46), sSize = UDim2.fromScale(0.64, 0.35), tSize = UDim2.fromScale(0.78, 0.44) },
	Knight     = { stretch = true, fPos = UDim2.fromScale(0.531, 0.85), fSize = UDim2.fromScale(0.68, 0.74), sPos = UDim2.fromScale(0.531, 0.85), sSize = UDim2.fromScale(0.68, 0.74), tSize = UDim2.fromScale(0.66, 0.62) },
	Beanie     = { fPos = UDim2.fromScale(0.531, 0.28), fSize = UDim2.fromScale(0.72, 0.34), sPos = UDim2.fromScale(0.531, 0.28), sSize = UDim2.fromScale(0.70, 0.34), tSize = UDim2.fromScale(0.66, 0.62) },
	Ushanka    = { fPos = UDim2.fromScale(0.531, 0.36), fSize = UDim2.fromScale(0.76, 0.38), sPos = UDim2.fromScale(0.531, 0.36), sSize = UDim2.fromScale(0.72, 0.38), tSize = UDim2.fromScale(0.68, 0.62) },
	Viking     = { fPos = UDim2.fromScale(0.531, 0.28), fSize = UDim2.fromScale(0.78, 0.36), sPos = UDim2.fromScale(0.531, 0.28), sSize = UDim2.fromScale(0.74, 0.36), tSize = UDim2.fromScale(0.80, 0.60) },
	TopHat     = { fPos = UDim2.fromScale(0.531, 0.22), fSize = UDim2.fromScale(0.74, 0.38), sPos = UDim2.fromScale(0.531, 0.22), sSize = UDim2.fromScale(0.74, 0.38), tSize = UDim2.fromScale(0.62, 0.58) },
	Propeller  = { fPos = UDim2.fromScale(0.531, 0.22), fSize = UDim2.fromScale(0.72, 0.36), sPos = UDim2.fromScale(0.531, 0.22), sSize = UDim2.fromScale(0.72, 0.36), tSize = UDim2.fromScale(0.62, 0.58) },
	Halo       = { fPos = UDim2.fromScale(0.531, 0.15), fSize = UDim2.fromScale(0.72, 0.28), sPos = UDim2.fromScale(0.531, 0.15), sSize = UDim2.fromScale(0.72, 0.28), tSize = UDim2.fromScale(0.60, 0.56) },
	Mohawk     = { fPos = UDim2.fromScale(0.531, 0.22), fSize = UDim2.fromScale(0.68, 0.34), sPos = UDim2.fromScale(0.531, 0.22), sSize = UDim2.fromScale(0.68, 0.34), tSize = UDim2.fromScale(0.56, 0.62) },
	Cowboy     = { fPos = UDim2.fromScale(0.531, 0.22), fSize = UDim2.fromScale(0.86, 0.36), sPos = UDim2.fromScale(0.531, 0.22), sSize = UDim2.fromScale(0.84, 0.36), tSize = UDim2.fromScale(0.82, 0.74) },
	Sombrero   = { fPos = UDim2.fromScale(0.531, 0.22), fSize = UDim2.fromScale(0.88, 0.36), sPos = UDim2.fromScale(0.531, 0.22), sSize = UDim2.fromScale(0.86, 0.36), tSize = UDim2.fromScale(0.84, 0.76) },
}
local DEFAULT_HAT_META = { fPos = UDim2.fromScale(0.531, 0.22), fSize = UDim2.fromScale(0.74, 0.36), sPos = UDim2.fromScale(0.531, 0.22), sSize = UDim2.fromScale(0.72, 0.36), tSize = UDim2.fromScale(0.64, 0.60) }
local SHIRT_SHEETS = {
	Tie = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAAsklEQVR42u3aQQ6CMBBAUWo4igsuxCm5EAvuMi7ckkiVCZa+tyZUmz/YEIcB6FepuDYS7/3LOmd/5/ijPU/3MAN9Gw+PZdQNRinfhV67TvX4ffhcV6/vCUBbZ4CY5/eNlsUZwBmA254BdsqNpLKvnpDSUwCeAJ0TgAAQAAJAAAgAASAABIAAEAAC4N6KLWhGyn8yR/vajm2aDl33XFc/AQgAASAABIAAEAB7vAhqR8qLoBcmnRhCVJWAYgAAAABJRU5ErkJggg==",
	Stripes = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAARElEQVR42u3WQREAAAjDMMC/56GDI5HQVztJirdGAoCv2gN4AAA8AB4AAA+ABwDAA+ABAPAAeAAAPAAeAAAPgAcA4JQFM18f+XVyObQAAAAASUVORK5CYII=",
	Hoodie = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAA10lEQVR42u3bwRHCIBCFYdahNorgRGmcKILm8OLRGDBkIfB/R0YFx+eaXVXM5rz35dt6Sqn3PtW37b33rzNYg0Mxxi6PE0IYtvfZGQjAiZzzpfs756Z+fi9e4r01B6B81K7DUAFAAEAAQAAwHdrAh7dxBOBG/wxwCMAiWka3XAOAAGCTjwARkZZ1UAFAAEAAQABAAPDALuDqd/y9uoMyaN8htKaQTAInpDmFtHcdSvOXrRr7cg0AAgACAAIAAoBl1PTKS88Bjv4bSAXAFqziO1ijWoEKgBZvNjwylf3IgRcAAAAASUVORK5CYII=",
	Overalls = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAA9klEQVR42u2bsQ6CMBRFb43Ozu4OfISzHwGrkx/k5Aof4cxHMLgzOzvUhagDTeElTUk4ZyKE+2joyQtpUycI4UfuuUzZOflZdbbMc5ji8vxed/djlqwlP6dOVICyLL0kNU0z1UQ/5DTkXIrJMYwLRtjwCRAAEAAQABAAEAAQABAAEADWQXQlsK7fkqTfgts0rLml1KcDAB1AkqpqZypszS2lPh0A6ABr4HC6hfbN9eoe/89J4T12c7Zvr44OAHSAXOyLc9b39y3/AIAAgACAAIAAgACAAIAAgACAAIAAkJToXoDhbJ8bckkHnurMIQJAdqyngS11PhVvQT+DM164AAAAAElFTkSuQmCC",
	Vest = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAAqUlEQVR42u3bOw6DMBAFQBzlijQ+4DY55KbBEkUKLIUC70yJkPjo8fBK0Lbieu/5pPONiPbP63ltlPa+sE8eyZpKYESMTe3OJ/fu46xOAwgAAoAAzMrcM3NPt1ADsPgU8FNrH6tuDYAAIACYAtAAmALQAAgAAoApAA2AKQANgAAgACy2BhgTQJW1wOnr40vGV9QaAFMACwagmqdUulcAAsDEq1y1+zuYwr6CkDcZxqe2agAAAABJRU5ErkJggg==",
	Racer = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAAi0lEQVR42u3boRGAMBBFwX8MnaDovxgUtQSDIBIEDLArY5KZvMRdhVNaay1J1nnu1qdlSZJUVb1p/8GV/tt4JcK9xG7xEF7d+RLv3vdr/AACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAC8zpXZwEq6mbxH1NMH8APwBRto6RZMhn4dkQAAAABJRU5ErkJggg==",
}
SHIRT_SHEETS.Checkers   = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAAdUlEQVR42u3YMQrAMAwDQKn0/19219AftL7bglcRgTozk0Pb85nX2f1n9yusJgACwGZNMjpx790PoAIQANa6daIdABWAAGAH0Il2AFQAAoAdQGfaAVABCAB2AHc7ACoAAcAO4G4HQAUgANgB3O0AqAAEgM96ALCvhUCsDzUuAAAAAElFTkSuQmCC"
SHIRT_SHEETS.Suspenders = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAABUklEQVR42u2bYQ6CMAxGgXgYLjTuwgm4i17I29Q/kBBEN0a7rPC+xMSQrC729evmXNugL02hl+X9+Hq3hWPJzrPcOURjPUj374RZxE6BYAp9s4Lm7Gf+jdVFEQpBJASZaZJE6mQ1zkQZ80rSNkFngNiOPesmFuqoeRtXsHQSADCWRaXWWP0AYNQKPFg/ABi1Ai/WDwCFbLvm6gcA5VbgyfoBQLkVeLN+ADC2cQ/VDwBKrcCj9S/ip2DjXQEOcLNW4Kn6AUAZAm/JBwAEAACAAADprPw97goAQHnbx2HQzXYEHlf+AKBQ/evEa/6NDACcWr/XVgAAmdaf8uwaADzn11HljqslfoL1xyDw4AI4gLGN1w5B/DRwyIw8GM98KP9lpR4GsQi8+Kr/KCg1AwEAhWy7VggAQMn6ve4KWtKrZ/1K8WTnQmf27eBYLACIJO3q18M/mRPLL7ySYe8AAAAASUVORK5CYII="
SHIRT_SHEETS.Jacket     = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAAlUlEQVR42u3YMRKDIBRF0Wcmq6RiaVRs0zSprDSjo4RzSscKrx9lSbLmgNZakqTWumyur9/rYRwvSyAABMCs3pZgDKWUQ/f33k0ATIDT36yz7X1TBfCnD8BHIAJAAAgAASAABIAAEAAC4HqPOQr+5Ux+9mNcEwABIAAEgAAQAAP/BvqlMwEQANNuAdyzRZoAtgAEwLQ+kfwXITGyd9wAAAAASUVORK5CYII="
SHIRT_SHEETS.Armor      = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAA80lEQVR42u2bSw6DIBBAa8N5OBCrORorDsSF2hWJJlChyFDLeys/CTPqcyBj3Lz3rwcsy5NbsDYmbYiIamDv/WF/dnytPHJxa2OWcu4Zz+wPxBhVbr61Nnt8dvyEc25I3BBC8dzZtZ/l/O14hiLY//A0JRo2BYB+CWYRCAgACAAIAAgACAAIAAgAmph906K13dhDrlkyI35tc6eU8+0F4B2o4y6tXQS4oBK19v174rVUoCECpARERM3yEML0C//nss4iEJgCavmVSkQFAAQABAAEAAQABAAEAAQABIChHDqBIz+CwGeu/hReO97G38FMAbAwb8njRovI3esZAAAAAElFTkSuQmCC"
SHIRT_SHEETS.Camo    = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAElElEQVR42t1bK3brMBCdd45MTEJEQkIeKTEOCfEiSrqDkOAuoTgkOyjJIkxCgk2CTUxETEwM3gOxXGksyyNb/qQiPUlrS/O7c2c0/bM7/f0HL7SqtNQ+B1Ho7d085tpnkYhVnhe/c3vaDT4386W8Yx5on68fG29KnOqMl2016X6Hu26oJJxPVqozM5+bSqO/fWXw9lU039/24WqNNIWhbfJWaamhwNLyMh9edbiXALsNvOpqIDVeF0rN4QzMSUkrUFAQhZPkagCA/JyR8jSO+KGI0YUUEkl5h3xBFOrI8V0MdhZvKSDNCgDwhwLP9wEcsn5YpUIwVUkqyRpD2h6fOjmD2sHmWNSgGO0APOYA96zJ/a45v8tIh2wZhBnDqPtkj0u7U2I+MBsHwJCKBT/mAQDfAHw/o/IsCi0yVE9fivVHCgeJcrqCL9uKHOVST486FUqH70KjR9x9RgCAG1RGZ+AoJY1Bo750OQgBfNbeU8Kbb2J2tThdg1z3sg39rlUE9MunOnaVlqA+cuIbjR9ITjF5GehV4ShaZFSb8vhtH2pR3xkB38Ui8jSRzNdXKbGpo/HV6vo1Na586fO9dnwTEjCK0Esb7Sx+IjfY2hk+VpAq/Fg55Lsu26qTsN32IXCLHC7p03eqNdmZwS9b0svfPcK9q+OoisZ9e9fKgVIdYEe5gDkYTOjBug5KaVdihvleE44hMKruf1b2pyiwr5fwZOwFuTy16ULKfCWmDCyH/Lk0kW4QwPeFhdoLONxLSB083RfMVWlpJFy+GjxTLJdbQxsiqfZMZUoyBCo5BfCYa+WPDVrPogCQ505LLwqhGkpDqdr4uO5OREFSnBoEuDH0auuYB63y9VdzgCGLx1xv2pyzVZ3PpYWtOm9c9r+PuTJP9WGRCC1y8pDelTJdcIzN+b5WXHanK5EIxImCRic2GPeZclyun3s5gHxYvlT+jHbmsslmRLyS8EdwU7t5SsFNpdra8v7UZ5MpUC1fSSng8bmDB7SvI01GlEbwFblYEdSrV5Nw+Lsh18hLNobGXntTUgcbcpDftrBib/twlR1MHnOrE5xQ5XMBTw5ALV1cykQf+Wupsg47g6/BT2qgYZ01zw1ofjHTS/Ex8LVkF0myCe4KX13Qj1OO9PprvHHe75gHLWM2+77giBvu9fM6/9vQixnJFYjVQb+PJlKbwbe7nCmlzzAgJfQ9f7iXrfkBkQjNBtT5APXvzvC8PzFNbYtE2FPAGAL0itO9miPUbWTpeEtM68xBQkdxgCG5ri+S5UCFGg2myZtm73wZB+niH1Vaar87cfotpCqny1CJ6iSuqM0obBMb+jZztEe7DUS5frkjnanZixgp+B2tMS1iqpEt4nxlXUNXxGBS6KXz/dhRa1/EqcuRum5AsQxdl2l9QUGxgQzERldovLx5Pm47Q2v/+neT3QVMlfPx8Kc2LEJISa0SagYuQRltt6UZLFcrPdQteUwiTf9kgkvWVV4GvX1li5OvoTwoHgFkMmLnvA9hc7FNH0hyhOVr87XPDM5aBfiEewo82mbx1mBQLMPcvEatIiJiI+s/htONQyGq2/wAAAAASUVORK5CYII="
SHIRT_SHEETS.Flannel = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAABAUlEQVR42u2ZwRGCMBBFvw4lUIKHVGIxFmQxVsKBEtKDXsyMRhaNgBL2vVPcQxacNfyHO0lXSTq3rR45xah3dWtdsk/im/5z1L333wtc06TFMZsQ3SdktG6tC/aZ1H+Guvf+nADOYQAYACADSLpkz6SSurX+ZJ85+k+pe+/f8BsY1rJf1VdnAYeuMy+8D2GzFtCH8PQ5fQ9L1/99/4MnQP7SYM0TDIRAYABgMQsoTf6k8Lr6cwJwAmQpNEYz8I0mf97FV9n/xQKSrlj6AoRAYADAjQXwXwAWAK4soCRVYgHV9+cEIAQCAwBkACwACwAsAAvAAoAQCAwAYAFYABYAm+cGkKRYZQtqNlQAAAAASUVORK5CYII="
SHIRT_SHEETS.Tuxedo  = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAAl0lEQVR42u3YQQqAIAAEwDZ6pf//h10rIvCQRs6ADzDXTc1CnXnyq/Wf29a8XWp93DFJMmgHx3JqAHoFIMlpdNvuF6M/YCml17ybhgbgnTPAMZEj3JwxqmV0BkAAEAAEAAGg5zsAGgDvAGgABAABwC0ADYBbABoAAUAAEAAEgL/cAuLyrwHwDvAlUzTSW8WrAfwCEACmtQMjjkU/gc4AmgAAAABJRU5ErkJggg=="
SHIRT_SHEETS.Jersey  = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAAv0lEQVR42u3aQQ6DIBBG4aHhKC68/2lc9C505RoLbRD53loxJI+ZHzDF4rz3vaw8/1cgCAACYE1y7YFSSlePTCmlnvdHf38023H0Zpw+ATCe1jVwxf38i0H+yeQLWAbA5BkgIkYvwVuVgFpPrvXcGQXAxZ48Y7vKDZMvT07dMgBkgJb9de9+HSoACAACgAAgAAgAAuC+5wD2/SoAVqwAzvqf9Y+C28Avme26VwsAAUAAyABCJwGETi0ABAABcPIBRxAk6c+ItJEAAAAASUVORK5CYII="
SHIRT_SHEETS.Polo = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAAr0lEQVR42u3ayw2DMBBAQW/kFmiDMiiaMmiDIpxbjlEEsmKzM2eEwHqC5RPbcbbyxb4u5Y7tOMvMnn7+9ZeNWmuXdh4R5QmefP6vQmoCSK5agrEv5b1nkDr6AvzbCENczxmkXl2AfV0+BxYR00/7ZgAEgAAQAAJAAORw60VQ5vcD6QPw3O8WgAAQAAJAAAgAASAABIAAEAACYHx+C59Az6+uAhhc76+ubgFmAARAWm8IBSNqc8eZJQAAAABJRU5ErkJggg=="
SHIRT_SHEETS.Suit = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAAqElEQVR42u3bMQ6EIBQAUTDeZCtajwN38TacycqzrL2bbKAE3tRWOH++CTHmnL+hkVpr03OllIAx2BwBAZp5T/adUrhTMv0KgFHZHcEYtH5/9Za4uwASbwWQgwBYWgCTrgAggCoQAOsKYOIVAARQg6UFOI8jfK7LKVoBWFYA+R+bn9vAf7dOXrYCgACYegXIvAKAACAACAACgACYmdjzbyAUAAQAATAND/TEHRqD7J91AAAAAElFTkSuQmCC"
SHIRT_SHEETS.LabCoat = "iVBORw0KGgoAAAANSUhEUgAAAIAAAAAgCAYAAADaInAlAAAAuElEQVR42u3YMQ6CMBSA4VfDZbpwK1bPxJm69xqudQATTUiMQaOW75vA8fFLS6PtMM9z43veMf9TcGgCEAACQAAIAAEggFWeauSpRkREzTlqzqblDUD3AaSUIqX0cL91TR+GrR9LKRFxWW7O5XYVMY4mZglAAAgAASAAuvwKGO32jxtAa81U7uw9+/j1eQ4e8XPLucjr/uFNag9gCaCHf7IAPqT3PZElwDkAAkAACAABIAAEgAA4iCtKeBR7nfRtKgAAAABJRU5ErkJggg=="
local SHIRT_STYLES = { "Tie", "Stripes", "Hoodie", "Overalls", "Vest", "Racer", "Checkers", "Suspenders", "Jacket", "Armor", "Camo", "Flannel", "Tuxedo", "Jersey", "Polo", "Suit", "LabCoat" }
local PANTS_SHEETS = {
	Belt = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAVUlEQVR42u3UsQmAQAwF0CjpXMTK/eewchFr7UWb45CDvFcGQj4hJAIAqGqKiKvyArKl6dzX1/qyHb+E7jk/W0M8h32FGt1c/Qdk7zP0BAEAAABgaDfuHgz+fzd3dAAAAABJRU5ErkJggg==",
	Cargo = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAn0lEQVR42u3XzQ1AQBCG4SHbhA504KwEh72ohAroxUEJ2tANVyF+MnYjMu/cRHybPNnMmKQuskUMVyrGCwDrAM6Xufrjqp9ERGRsSm4AAAAAAMAvp8C+oz+ps64fIuNNpuYct33o/P1IbIf58n2IDE2m9hx6AAAAAAAA/wHK8RRixH2VeQAIsdLGWItjr9r0AAAAAAAAAAAAAAAAALBZK80NId1wYFiZAAAAAElFTkSuQmCC",
	Track = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAUElEQVR42u3QsQ0AIAwDwYT9dw4tSgmiyv0AtnRZVRVHmRk/a3dXf33jZWvF8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwIQ21CsKP2d3+KcAAAAASUVORK5CYII=",
	Shorts = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAATklEQVR42u3SMQ2AUBAFwYVgAi8oQhCK8IIM8AAJzZ/p3xWbm6q7gc0NToDRAyzrdrweX+de1ZcbPkAAAQQQQAABBBBAAAEEAAAAAH7xAM3FBQ6IMmvoAAAAAElFTkSuQmCC",
	KneePads = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAVUlEQVR42u3WMQqAMAwF0CieMgfMNe3aQRQq6JD3ppaSlH4oJAIAAOhom9bnYl382OPtm+OYN5n5WF1Vt+df9Vhxde/e/QsIQAACEIA5oPMcAAAATQ1m/w8TzHg0FQAAAABJRU5ErkJggg==",
	Cuffs = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAPklEQVR42u3SsRGAQBDEMB9D/y0/PUBAcFIBG3i2AAAAAACALaY6mwNc2x9wn/P+ADNT1ZcNDxBAAAEE+NEDpPkHDnA51Y8AAAAASUVORK5CYII=",
	CheckerPants = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAaklEQVR42u3WMQqAMBAF0b/i/a+8tiFNQBs173dhu4EJU93dGVZV4zPT+Xf3I5sPgN0BVJK+69R8++KfQAEANt/51KnVv6ADKACADtABFABAB+gACgCgA3QABQDQATqAAgDoAB1AAQBeswsXasUxP8hj0AAAAABJRU5ErkJggg==",
	Jeans = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAkUlEQVR42u3VMQqAIBiG4d9ob2538BDNncSpocM0NHWSTuLgJTqBzZFBiUTh+20Kijz8+Km2m4M8jJ+n6L4eRvlbKik8AJQOoIz1IfWwW7SIiBjrX3/45tbDujE9E5CS+ko0lrvKOe/iDwAAAAAAAOCFGsxZS1+pOCYAAAAAAAAAAAAAAAAAAAAAAAAAAACAc3aXwxSOY2aQUQAAAABJRU5ErkJggg==",
	CamoPants = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAACmUlEQVR42uVYrZKrMBg9dyeYGAymBrNmTXUNpg9xzb7BGvR9hNWYvkFNHwJTg8ZcswaDwWAwiLtiG5qkBPLHNDP3m6lomSbhnO8738n3K81f/wHAWA/gI9pT2MZHGwnfT7tR69kzgiDAyCqRjOvBngyZWBZ5EuO0G8MDYKwHlNz7HoeNM0CFkBPaSaxmQXr27HjIAFb7OrXaFF8AgDR/RVbdmSu6HgCwy9PbD/30n6LrkRuAsE9j7Fv/enF5j5FsrQFt0XgvD1OhVhF6kTNgqjUmQGnsLDSqWGKSfyn50FsA9RLtqVPL4+M43D++1ry8x4Jy5541RFkCRdcLL5EcE+F5V3bCd1b/vl6cZUqyUXmy81trQFYNOHPMl1SdzjolYmKQbEBWrUd4s+HSElWH0jE1WTUYaY5P4xSkExSy4txvapuJbmrJNR9q8L5BBzRizMgtas8HZ+ZpImNHtbSCb9l107tZ4cm5LbDO2tLbp95mOvV4PVDAgyW/HqjAPt+9fp/7WVEka+JiehNba5ehhbUI8m2vpEB+S82LpTub0x+5LI7NukNlzGbVgL9/Ur8A/NTYc29zcp27GjDCW8uiaFbv32+fPxecliL4YGcFgJOilMlSatugysTGtWfL5qakAWgAL4gRAJR3oE4YvV5j55zmdQYY1Vq64i0AwOZkpncBm27h0up8gkt82MuSQujjso6UAetFUHcBns2SPrK5xUidbGFqZMbX0pLt09Z+RmgmQBGnWqyenzWuAxiyxSFcR+2TN7GYBo/1gGJuLV8A8GXBxuImtb3E2HQZO/dGUx0+9Ys5O92pyVoEwPYiw2+ikw2P+0RK0H1frl7wn0eQIzE+1eVOpK0ft3XWMtAYANMU9DkmNwFOd/9v2lYljsSiN28AAAAASUVORK5CYII=",
	Khakis = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAYUlEQVR42u3SMQ2AQBREwYVgAgc4oD4JFDQoQQJukIA0zgMVyZ/XbzPZ4VjnN4UbUzwA1QGmvS2fx9v1JEnus3kAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/rgMgIAWpEa0MngAAAABJRU5ErkJggg==",
	Pajamas = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAZ0lEQVR42u3SsQ1AABCG0Z9VKNiLqdiLglloRUUoJN5XXu6alyuabtlyaBqqJEnbr7kyP/f0/s7+Gztlfh4AAA+axzrzWPsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC+3w4DrRrXJTRFZwAAAABJRU5ErkJggg==",
	ArmorLegs = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAjElEQVR42u3W2wmAMAyF4SqdpzNltMyUhfS1IPZigiL9z5sIp/BhTTZVPdLC2dPiAQAAR0QkiQhfAAAAAAAAAAD8M7me6aNR1du9wNvxpMtzXq4fzKxbVEppvo/omOkaSes8/gEAAAAAAOwBk+MpYsS93dUF6C0mEcvNV11cAQAAAAAAAAAAAAAArjkB9uUepZRGglkAAAAASUVORK5CYII=",
	Sweatpants = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAcElEQVR42u3VsQ3AMAhE0SPKRCzk1WAmBiJF2lSRC1v+V9GY4gmDRUTr4Fw6PACcDnD/fTjGkJlJkrrfNZKZ+wG4+7RmM3vxBQAAAAAAVj6DVfVZMwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMDKeQCkqA9DpQboHAAAAABJRU5ErkJggg==",
	Slacks = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAXUlEQVR42u3SIRLAIBAEwSXPPMXTUHwTdCwqKXrcijNd15KsHDTGeO3ee/7Yk8sDcDtAq6p1ejznTJJUlQ8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAODbbeS8CUtzmynDAAAAAElFTkSuQmCC",
}
local PANTS_STYLES = { "Belt", "Cargo", "Track", "Shorts", "KneePads", "Cuffs", "CheckerPants", "Jeans", "CamoPants", "Slacks", "Khakis", "Pajamas", "ArmorLegs", "Sweatpants" }

local FACE_SHEETS = {
	Chill = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAZUlEQVR42u3ZSw6AIAwFQDDe/8r1BkZJiwRn1nxKXtlAawAAMF1/MCZezomBPTLnr+b2PIce/JYABCAABCAAAADgP6peGqNgj5hQ9/Qaz4GFK4veSWQGsMrtWv1voG/eVAAAQIIL4eoLFmwSEtQAAAAASUVORK5CYII=",
	Angry = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAnUlEQVR42u3YgRGAIAhAUencf2VawLtIMND+G4AURNPWAABYS0nB2LU4aRoY58hF141BxPFx+XHnPOZPgpMZkXidGONOnSCzk7MkV4MSv3vSzXPswduAOFewDM6NEztALYewZ9tqheJWJJ4C4KPfUFAACgAAAAAkXv91YXwNHmsVpnlxDyjeAZ5XycgXzZ1eR1+NlQ5IRgEAAACQ4AbO5h8Z3JQe6AAAAABJRU5ErkJggg==",
	Surprised = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAcElEQVR42u3YYQqAIAwGUI3uf+V1AYtaUgPf+60z+RRmrQEArKjfGBMP50RijZnzq7ncz+YM/ksAAhAAAhAAAgAA+NDbH2Uz6sbkb6wmtKGF7alIYxxq77nDOqqXrVX2Gpzs0Q3wEhYAuiBdEADAWg58uxMemdS9tgAAAABJRU5ErkJggg==",
	Happy = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAfElEQVR42u3Y0Q2AIAwFQGrcf+W6gQECQuTuW4rwaIKWAgBwoqh4JhvHZMccI8fv5nU9lzO4lgAEIAAEIAAEAADwodYfazPmycHvvFrTelxDF7urIs2+RoiIYbVram3VBpXr0gG+hAWAW9C5t6CYUbSxfv5o80cfXABglgf4pxYZ+cnDVwAAAABJRU5ErkJggg==",
	Sad = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAlElEQVR42u3XOxLDIAwFQMTk/ldWulT5YAKOIbs9NjxJHlMKALCNFEG7OincHFiI3LkZbxNCiBfr4k+n6G0G0buwYxNxMPQoe3l6vmgI7WgwvUH2vm/F4B8NWRs/JWfYreObzloLS/0FoQAKAAAAJ17/c9Kzc/A+r+Tj2dwDFpiA/LKrY2AXxYKdHybgwhQAAIAfuAPZuRwWomOH1wAAAABJRU5ErkJggg==",
	Wink = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAcUlEQVR42u3XUQrAIAgA0Bzd/8rtBAMJV7S9911SRmatAQDAcpEYMybmkHRJgQP4tV4cbxSXu5NLX2ovboBH2BsAAKANfWo/Z1vPihhvxFrx+UqtURu6WZ842ZVf9pOl9hULEhSF8eNLyVeCAAAANrgBVOgPFRhMvisAAAAASUVORK5CYII=",
	XD = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAvklEQVR42u2YWxLEIAgEndTe/8rkAskubsAH6f62UAYQtDUAAAAAyMOQ4JpjgHDWYcveloxyLtTDjZSwfnfxlSnMEzErBuLWp2hBo8SrFISvvkRnZ7RwOwfCdXYliREhXIUq+OlDdnMc3T9K9YBIIWxQ1ZS4lmbN5G96rPEwBYAV6J2CMvawhDNvc78f5OBcPu6wWl+iSgq167W3TBk4/aICJkMACABTEFPQxClIWYbbf59vu4sflbQAAACQzQlopjcKMVXJogAAAABJRU5ErkJggg==",
	Silly = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAnUlEQVR42u3YwRGCMBAFUOJQgIVZkCVYEIXZQTx7QSKLG8N7N2bIwvIhBKYJAOCMyoZ9auOY+sUxIsf3ZrWfi3swlwAEIAAEIAAEAADAebT+2TziODX4nLM19eM7INkcVeh5X962r49bSo0erfU1BzzudWeNElCj12n9Y1+moGQCEIBl6NHLrvKjGv+4JA15B5SAC1cGvPgj9wWM4QXU5hYs7oAL/wAAAABJRU5ErkJggg==",
	Dizzy = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAwklEQVR42u2YQRbDIAhExfvfmWy7aBrBMZHm//2gjA9UWgMAAIAy+E0ahXZ7r3owgA8EzmgU2l3N91859kCAT6EJNQrtjthIbpYooRUahbZSG7LRFmQJM2zCQPsz8y9z6g0eJXsJqzUKbZUWFL6Ezy4UlUahrWB+Kqdvp+eJZ6hPVI+3us9QX1HVfMTesXcAAACAhYzMWq4GZLMDtGj83edDHvGKWVDRClCu4wv2XObzZaIF7mxJ1X/CjKMBAAAA4GkObAJQ4xP6L/gAAAAASUVORK5CYII=",
	Robot = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAmUlEQVR42u3Wyw3CMAwA0Bh1BdZgDIZmjK7BEOHC5wJtKiwS1PdOTSs5cdwoLgUAYI/iw/v6w/lq0ppHsSmfg3+wr2np43m+pkxyOR3Lt/OsxRhNa05OQGcKoAAKgDZUGwoAoA3NbkkjMX78yb4256QN7WxqLml9FTUinuOl56zYW2INdQzua3+3P4+xE9CZAriEXcIAAPtzA7GKMx1PeaC/AAAAAElFTkSuQmCC",
	Cool = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAe0lEQVR42u3YWw7AEBAFUBr737IugahHcc5vI1WXkWkIAAA3ioXnuXEcldLP5nNa4MXvSRZwraehRFnMiQH0uFPixPE73LFxZAAsPgEIAACAPTu1r3Lnd+QNu+LqOesDFkuNu3rkiTlN7hHA6tK22w+5WLu5lCAAALjPC4qhCyib5pNNAAAAAElFTkSuQmCC",
	Sleepy = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAT0lEQVR42u3YwQkAIAgAwGr/nW2CiEIo8O4baqIvWwMAAIBK+uY9DuPisk5W/G+2/Qw7+JYBAAAAUMvNjSWSc0by/3607NEp4jEDAACAeiYAqAcKebK4wgAAAABJRU5ErkJggg==",
	Shocked = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAiklEQVR42u3XSw6EMAgAUDHe/8qddZPJ1I5EWLy3taiI/XAcAECJWFwfm3Hjz+dkxXezzOf0D9a6liUccxEjInV8dny7KbDI59YMiIitD7E7Pju+3Tr/Ix9LUDEF6L4HfFvHssdnx3ffBxxDHUMBAIBCTxukjPuP5Hft3oRNNGLFFEABFAAAAF72AYf9Iyl59NH/AAAAAElFTkSuQmCC",
	Nerd = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAuElEQVR42u2YyxKAIAhFten/f5k2bXpYEDpinrNsECPigqYEAAAAMCO58FyM68WxnzjfNSqquBb+wb6sjymU+yTmnKvY11obugxe4lpVtb8b3zgTo/3Xfd5KuleWxBsfEhRZgho04RYDQ8QhRv1NVAmwSonV3rtu5H7AGMoYCgAAAADzoZ2tpaF/zgHQDxIwiARdyut8r7FftXpk4uCzgr9QclSKjQoYtQIaNEr5QeOdMTYAAIAx2QCqCUMS+oydgwAAAABJRU5ErkJggg==",
	Smug = "iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAAeElEQVR42u3Y2w2AIAwAQGrcf2WcQCOhCujdLzZo+khqKQAA8Lq4OKuNsbXjroz42dz6nk0NjiUBE4+gs1aK5Oez42cfRaEDjCAkAACAyTfh3s2v957VNuOm97UHDLZ3VvZTHfMlNSsBI0fbSj/koqW4jCAAAPifA4HwDxkJEAczAAAAAElFTkSuQmCC",
}
local FACE_STYLES = { "Classic", "Chill", "Angry", "Surprised", "Happy", "Sad", "Wink", "XD", "Silly", "Dizzy", "Robot", "Smug", "Cool", "Sleepy", "Shocked", "Nerd" }

local localCustom = {
	face = nil,
	hat = nil,    -- nil or hat style name (or "None")
	shades = nil, -- nil or true/false
	shirt = nil,  -- nil or shirt style name (or "None")
	pants = nil,  -- nil or pants style name (or "None")
	skinColor = nil,
	torsoColor = nil, -- { mode="fill"/"tint", color=Color3 }
	legsColor = nil,
}


-- ============================================================================
-- BASE64 & ASSET HELPERS
-- ============================================================================
local B64_LOOKUP = {}
do
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #chars do
		B64_LOOKUP[string.byte(chars, i)] = i - 1
	end
end

local function decodeBase64(data)
	local out = {}
	local n = 0
	local buf = 0
	local bits = 0
	for i = 1, #data do
		local c = string.byte(data, i)
		local v = B64_LOOKUP[c]
		if v then
			buf = buf * 64 + v
			bits = bits + 6
			if bits >= 8 then
				bits = bits - 8
				local byteVal = math.floor(buf / (2 ^ bits)) % 256
				n = n + 1
				out[n] = string.char(byteVal)
				buf = buf % (2 ^ bits)
			end
		elseif c == 61 then
			break
		end
	end
	return table.concat(out)
end

local function loadDOSEmbedded(fileName, b64)
	if type(b64) ~= "string" or b64 == "" then return nil end
	local customFn = (type(getcustomasset) == "function" and getcustomasset)
		or (type(getsynasset) == "function" and getsynasset)
	if not customFn or type(writefile) ~= "function" then
		return nil
	end
	local okW = pcall(writefile, fileName, decodeBase64(b64))
	if not okW then return nil end
	local okU, url = pcall(customFn, fileName)
	if okU and type(url) == "string" and url ~= "" then
		return url
	end
	return nil
end

local function resolveDecalToImage(assetIdStr)
	if assetIdStr == "rbxassetid://0" or assetIdStr == "" then
		return assetIdStr
	end
	if type(game.GetObjects) == "function" then
		local ok, objs = pcall(function()
			return game:GetObjects(assetIdStr)
		end)
		if ok and type(objs) == "table" and objs[1] then
			local obj = objs[1]
			if obj:IsA("Decal") or obj:IsA("Texture") then
				local tex = obj.Texture
				obj:Destroy()
				if tex and tex ~= "" then return tex end
			elseif obj:IsA("ShirtGraphic") then
				local tex = obj.Graphic
				obj:Destroy()
				if tex and tex ~= "" then return tex end
			else
				obj:Destroy()
			end
		end
	end
	return assetIdStr
end

local function resolveSheetAsset(sheetCfg)
	local customFn = (type(getcustomasset) == "function" and getcustomasset)
		or (type(getsynasset) == "function" and getsynasset)
	if customFn and type(isfile) == "function" and sheetCfg.CustomFile then
		local okExists, exists = pcall(isfile, sheetCfg.CustomFile)
		if okExists and exists then
			local okUrl, url = pcall(customFn, sheetCfg.CustomFile)
			if okUrl and type(url) == "string" and url ~= "" then
				return url, true
			end
		end
	end
	return resolveDecalToImage(sheetCfg.AssetId), false
end

local function getBillboardParent()
	local okCore = pcall(function() return CoreGui.Name end)
	if okCore then return CoreGui end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local function getScreenGuiParent()
	if type(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then return hui end
	end
	local okCore = pcall(function() return CoreGui.Name end)
	if okCore then return CoreGui end
	return LocalPlayer:WaitForChild("PlayerGui")
end


local resolvedSheets = {}
for name, cfg in pairs(CONFIG.Sheets) do
	local url, isCustom = resolveSheetAsset(cfg)
	local defaultW = isCustom and 1280 or (1024 / cfg.Frames)
	local defaultH = isCustom and 1280 or math.floor(1024 / cfg.Frames + 0.5)
	resolvedSheets[name] = {
		url = url,
		frames = cfg.Frames,
		cellW = defaultW,
		cellH = defaultH,
		labels = {},
	}
end
local HEAD_WHITE_B64 = "iVBORw0KGgoAAAANSUhEUgAAAUAAAABACAYAAABr564eAAABi0lEQVR42u3bywqDMBAFUFP6/7+cbqSI6EIT83DOWRYpToIztyUuCwAAAAAAAAAAADCrVPG78otqUb/61R/AxxIAEmDh5Mu57wBMKfWahOpXf+T6JUCAaAlwiMnXcRKqX/2R6z9cj9l6mQQIhPW1BMDsSTillO8kQQkQkAABZkt+/5tZ7+NqEpQAAQmwwW/0w45d63r6sl/We0YSICABtppU+8/3k+vq9YyVROxX3/VGAgTQAAE0QAANEEADBNAAAQ0QIJzHzwFu3tE7/Lz0evqyX2Ott/OAEiDAGAnwbiKQIOZMJlhvCRBAAwTQAAE0QAANEEADBNAAAZqqfg7w7CR66bmlp76XZ9k36yYBAkRIgGfvJNZ+R9EkHDup2Lc5niMJEEACbDPBJL/YiYYxniMkQEACNPmxv29ZZ0lRAgQYIwECr5TWxJlH+CWwSb6XIrAECEiAAKVJsPd9XCUBArG7d6Gp/wNQv/rVH5cECEiAtSbhS2pRv/rVLwECAAAAAAAAAAAAAAAAQG8//V2xZDSsXzAAAAAASUVORK5CYII="
local ARMS_WHITE_B64 = "iVBORw0KGgoAAAANSUhEUgAAAQAAAABACAYAAAD1Xam+AAAA6UlEQVR42u3cwQ3AMAgEQRO5/5ZJFz4kZhqIxGON8qBOXoe/X2c381/sMwLY6455hvrtQ1Tl4TF/bAAgAIAAAAIACAAgAIAAAAIACAAgAIAAAAIACAAgAIAAAAIACAAwyDWCuDaC1fOPnkayAYANgPgz5Caf+dsAAAEABAAQAEAAAAEABAAQAEAAAAEABAAQAEAAAAEABAAQAEAAQAAAAQC2cRNwCDf6zN8GANgAtj0+4e+3+fsHAAgAIACAAAACAAgAIACAAAACAAgAIACAAAACAAgAIACAAAACAAww4RpKm4H5YwMAHvsBrK8Tj+6s4MgAAAAASUVORK5CYII="
local headWhiteUrl = loadDOSEmbedded("dos_skin_head_white.png", HEAD_WHITE_B64)
if headWhiteUrl then
	resolvedSheets.HeadWhite = { url = headWhiteUrl, frames = 5, cellW = 64, cellH = 64, detected = true, labels = {} }
end
local armsWhiteUrl = loadDOSEmbedded("dos_skin_arms_white.png", ARMS_WHITE_B64)
if armsWhiteUrl then
	resolvedSheets.ArmsWhite = { url = armsWhiteUrl, frames = 4, cellW = 64, cellH = 64, detected = true, labels = {} }
end
local FP_ARM_B64 = "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAA+UlEQVR42u2WXQ4DIQiEYU6xZ9n7x7N4C/tkY7N/tIKQlHkyJviRIWMgSqVSqVQq9a/iH+uawhszUuN/W9xqrYfLbdtWGaHO5xnwQiPM+KwBvmhEwwxzPkuzJm1kgKsYYM1/NKCUQvu+f1ze5JCIiEopRES9bsYEcz5Lm+gP1lrfsPE8grsUDDDniwxorZ0XM5+ClU0w5UPyUXbQme7gWruKJR80N5pDPi8abCZLgQIfGlNYsbFa8RFhCp58RJiCJx9RsujFR5QsevERJYtefETJohcfUbLoxUeULHrxESWLXnxEyaIXH1Gy6MVHlCx68WHVmWQKlpLyXwMwzCuLmP5FAAAAAElFTkSuQmCC"
local fpArmUrl = loadDOSEmbedded("dos_fp_arm_90s.png", FP_ARM_B64)

local function setLabelRect(sheet, imageLabel, frameIndex)
	if sheet.frames == 1 then
		imageLabel.ImageRectSize = Vector2.new(0, 0)
		imageLabel.ImageRectOffset = Vector2.new(0, 0)
		return
	end
	local inset = (sheet.cellW <= 128) and 1 or 2
	local w = math.max(1, sheet.cellW - inset * 2)
	local h = sheet.cellH
	local ox = frameIndex * sheet.cellW + inset
	imageLabel.ImageRectSize = Vector2.new(w, h)
	imageLabel.ImageRectOffset = Vector2.new(ox, 0)
end

local function applySheetFrame(sheetName, imageLabel, frameIndex)
	local sheet = resolvedSheets[sheetName]
	if not sheet or not imageLabel then
		return
	end
	for _, s in pairs(resolvedSheets) do
		s.labels[imageLabel] = nil
	end
	if imageLabel.Image ~= sheet.url then
		imageLabel.Image = sheet.url
	end
	sheet.labels[imageLabel] = frameIndex
	setLabelRect(sheet, imageLabel, frameIndex)
end

local function detectSheetDimensions(sheetName, sampleLabel)
	local sheet = resolvedSheets[sheetName]
	if not sheet or not sampleLabel or sheet.url == "rbxassetid://0" or sheet.frames <= 1 or sheet.detected then
		return
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ sampleLabel })
		end)
		local deadline = os.clock() + 4
		while os.clock() < deadline do
			if not sampleLabel or not sampleLabel.Parent then
				return
			end
			local okSize, contentSize = pcall(function()
				return sampleLabel.ContentImageSize
			end)
			if okSize and typeof(contentSize) == "Vector2" and contentSize.X > 0 and contentSize.Y > 0 then
				sheet.cellW = contentSize.X / sheet.frames
				sheet.cellH = contentSize.Y
				sheet.detected = true
				for lbl, frameIdx in pairs(sheet.labels) do
					if lbl and lbl.Parent then
						setLabelRect(sheet, lbl, frameIdx)
					end
				end
				return
			end
			task.wait(0.1)
		end
	end)
end


local SKIN_PALETTE = {
	Color3.fromRGB(255, 255, 255), -- Classic yellow
	Color3.fromRGB(255, 85, 85),   -- Red
	Color3.fromRGB(255, 160, 65),  -- Orange
	Color3.fromRGB(115, 255, 115), -- Bright green
	Color3.fromRGB(255, 215, 175), -- Peach / tan
	Color3.fromRGB(185, 125, 75),  -- Brown
	Color3.fromRGB(255, 130, 150), -- Coral / salmon
	Color3.fromRGB(205, 205, 205), -- Pale / grey-yellow
	Color3.fromRGB(95, 60, 35),    -- Dark brown
	Color3.fromRGB(95, 165, 255),  -- Sky blue
	Color3.fromRGB(185, 115, 255), -- Lavender
	Color3.fromRGB(125, 245, 200), -- Mint
}

local OUTFIT_PALETTE = {
	{ mode = "tint", color = Color3.fromRGB(255, 255, 255) }, -- Original blue / green
	{ mode = "fill", color = Color3.fromRGB(40, 200, 215) },  -- Cyan / teal
	{ mode = "fill", color = Color3.fromRGB(165, 65, 215) },  -- Purple / violet
	{ mode = "fill", color = Color3.fromRGB(45, 45, 55) },    -- Charcoal / black
	{ mode = "fill", color = Color3.fromRGB(220, 40, 40) },   -- Red
	{ mode = "fill", color = Color3.fromRGB(235, 120, 30) },  -- Orange
	{ mode = "fill", color = Color3.fromRGB(240, 205, 45) },  -- Gold / yellow
	{ mode = "fill", color = Color3.fromRGB(45, 185, 70) },   -- Green
	{ mode = "fill", color = Color3.fromRGB(235, 95, 175) },  -- Pink / magenta
	{ mode = "fill", color = Color3.fromRGB(235, 235, 235) }, -- White
	{ mode = "fill", color = Color3.fromRGB(25, 55, 125) },   -- Navy blue
	{ mode = "fill", color = Color3.fromRGB(85, 110, 45) },   -- Olive
}

local function getPlayerAppearance(player)
	if player == LocalPlayer then
		local white = Color3.new(1, 1, 1)
		return {
			skin = localCustom.skinColor or white,
			torso = localCustom.torsoColor or { mode = "tint", color = white },
			legs = localCustom.legsColor or { mode = "tint", color = white },
		}
	end
	if not CONFIG.TintOtherPlayers then
		local white = Color3.new(1, 1, 1)
		return {
			skin = white,
			torso = { mode = "tint", color = white },
			legs = { mode = "tint", color = white },
		}
	end

	local seed = (player.UserId ~= 0 and math.abs(player.UserId)) or #player.Name * 997
	local rng = Random.new(seed)
	return {
		skin = SKIN_PALETTE[rng:NextInteger(1, #SKIN_PALETTE)],
		torso = OUTFIT_PALETTE[rng:NextInteger(1, #OUTFIT_PALETTE)],
		legs = OUTFIT_PALETTE[rng:NextInteger(1, #OUTFIT_PALETTE)],
	}
end

local function createPartLabel(parent, name, sheetName, frameIndex, size, pos, zIndex, styleCfg, addLegDivider)
	local sheet = resolvedSheets[sheetName]
	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BorderSizePixel = 0
	img.Image = sheet.url
	img.ScaleType = Enum.ScaleType.Fit
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Size = size
	img.Position = pos
	img.ZIndex = zIndex
	pcall(function()
		img.ResampleMode = Enum.ResamplerMode.Pixelated
	end)

	local divider = nil
	if typeof(styleCfg) == "table" and styleCfg.mode == "fill" then
		img.ImageTransparency = 1
		img.BackgroundTransparency = 0
		img.BackgroundColor3 = Color3.new(0, 0, 0)

		local inner = Instance.new("Frame")
		inner.Name = "FillInner"
		inner.BorderSizePixel = 0
		inner.BackgroundColor3 = styleCfg.color
		inner.AnchorPoint = Vector2.new(0.5, 0.5)
		inner.Position = UDim2.fromScale(0.5, 0.5)
		inner.Size = UDim2.fromScale(0.95, 0.95)
		inner.ZIndex = zIndex
		inner.Parent = img

		if addLegDivider then
			divider = Instance.new("Frame")
			divider.Name = "LegDivider"
			divider.BorderSizePixel = 0
			divider.BackgroundColor3 = Color3.new(0, 0, 0)
			divider.AnchorPoint = Vector2.new(0.5, 1)
			divider.Position = UDim2.fromScale(0.5, 1)
			divider.Size = UDim2.fromScale(0.04, 0.88)
			divider.ZIndex = zIndex + 1
			divider.Parent = img
		end
	elseif typeof(styleCfg) == "table" then
		img.BackgroundTransparency = 1
		img.ImageColor3 = styleCfg.color or Color3.new(1, 1, 1)
	else
		img.BackgroundTransparency = 1
		img.ImageColor3 = styleCfg or Color3.new(1, 1, 1)
	end

	applySheetFrame(sheetName, img, frameIndex)
	img.Parent = parent
	return img, divider
end

-- ============================================================================
-- HELD TOOL VISUALS (2D Box Icon OR Solid-Color 3D Model Fallback)
-- ============================================================================
local function restoreToolVisuals(rig)
	if not rig or not rig.savedToolState then
		return
	end
	for inst, state in pairs(rig.savedToolState) do
		if inst and inst.Parent then
			pcall(function()
				if state.Transparency ~= nil then
					inst.Transparency = state.Transparency
				end
				if state.Color ~= nil then
					inst.Color = state.Color
				end
				if state.Material ~= nil then
					inst.Material = state.Material
				end
				if state.TextureID ~= nil then
					inst.TextureID = state.TextureID
				end
				if state.TextureId ~= nil then
					inst.TextureId = state.TextureId
				end
				if state.CastShadow ~= nil then
					inst.CastShadow = state.CastShadow
				end
			end)
		end
	end
	table.clear(rig.savedToolState)
	rig.styledTool = nil
	rig.styledToolMode = nil
end

local function applyToolVisuals(rig, tool)
	if not tool then
		if rig.styledTool then
			restoreToolVisuals(rig)
		end
		rig.toolIcon.Visible = false
		return false
	end

	local texId = ""
	pcall(function()
		texId = tool.TextureId
	end)
	local hasIcon = (type(texId) == "string" and texId ~= "")
	local desiredMode = hasIcon and "icon" or "hidden"

	if rig.styledTool == tool and rig.styledToolMode == desiredMode then
		if hasIcon then
			rig.toolIcon.Image = texId
			rig.toolIcon.Visible = true
		else
			rig.toolIcon.Visible = false
		end
		return hasIcon
	end

	restoreToolVisuals(rig)
	rig.styledTool = tool
	rig.styledToolMode = desiredMode

	-- Hide the 3D tool model either way (tool continues working normally)
	for _, desc in ipairs(tool:GetDescendants()) do
		if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
			rig.savedToolState[desc] = { Transparency = desc.Transparency }
			desc.Transparency = 1
		end
	end

	if hasIcon then
		rig.toolIcon.Image = texId
		rig.toolIcon.Visible = true
	else
		rig.toolIcon.Visible = false
	end
	return hasIcon
end

-- ============================================================================
-- RIG LIFECYCLE
-- ============================================================================
local function restoreRig(rig)
	if not rig then
		return
	end
	if rig.descConn and rig.descConn.Connected then
		rig.descConn:Disconnect()
	end
	restoreToolVisuals(rig)
	if rig.savedParts then
		for inst, origVal in pairs(rig.savedParts) do
			if inst and inst.Parent then
				pcall(function()
					if inst:IsA("ForceField") then
						inst.Visible = origVal
					else
						inst.Transparency = origVal
					end
				end)
			end
		end
		table.clear(rig.savedParts)
	end
	for _, lbl in ipairs({ rig.head, rig.torso, rig.leftArm, rig.rightArm, rig.legs }) do
		if lbl then
			for _, s in pairs(resolvedSheets) do
				s.labels[lbl] = nil
			end
		end
	end
	if rig.humanoid and rig.humanoid.Parent and rig.origDisplayDistanceType then
		pcall(function()
			rig.humanoid.DisplayDistanceType = rig.origDisplayDistanceType
		end)
	end
	if rig.nameBillboard then
		rig.nameBillboard:Destroy()
	end
	if rig.billboard then
		rig.billboard:Destroy()
	end
end

local function hideDescendantIfCharacterPart(desc, savedParts)
	if desc:FindFirstAncestorOfClass("Tool") then
		return
	end
	if desc:IsA("ForceField") then
		if savedParts[desc] == nil then
			savedParts[desc] = desc.Visible
		end
		desc.Visible = false
		return
	end
	if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
		if savedParts[desc] == nil then
			savedParts[desc] = desc.Transparency
		end
		desc.Transparency = 1
		pcall(function() desc.LocalTransparencyModifier = 1 end)
	elseif desc:IsA("Decal") or desc:IsA("Texture") then
		if savedParts[desc] == nil then
			savedParts[desc] = desc.Transparency
		end
		desc.Transparency = 1
	end
end

local function hideCharacterParts(character, savedParts)
	for _, desc in ipairs(character:GetDescendants()) do
		hideDescendantIfCharacterPart(desc, savedParts)
	end
end

local function buildRigForPlayer(player, character)
	if playerRigs[player] then
		restoreRig(playerRigs[player])
		playerRigs[player] = nil
	end
	if not enabled or not character then
		return
	end

	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not hrp or not humanoid then
		return
	end

	local savedParts = {}
	hideCharacterParts(character, savedParts)
	local descConn = character.DescendantAdded:Connect(function(desc)
		if enabled then
			hideDescendantIfCharacterPart(desc, savedParts)
			task.defer(function()
				if enabled and desc and desc.Parent then
					hideDescendantIfCharacterPart(desc, savedParts)
				end
			end)
		end
	end)

	local appearance = getPlayerAppearance(player)

	local bb = Instance.new("BillboardGui")
	bb.Name = "ESpritesBillboard_" .. player.Name
	bb.Adornee = hrp
	bb.Size = UDim2.fromScale(CONFIG.BillboardWidth, CONFIG.BillboardHeight)
	bb.StudsOffset = CONFIG.StudsOffset
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	pcall(function() bb.Brightness = 1.15 end)
	bb.ResetOnSpawn = false
	bb.Parent = getBillboardParent()

	local root = Instance.new("Frame")
	root.Name = "Rig"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = bb

	local legs, legDivider = createPartLabel(
		root, "Legs", "Legs", 0,
		UDim2.fromScale(0.50, 0.38),
		UDim2.fromScale(0.50, 0.77),
		1, appearance.legs, true
	)
	local torso = createPartLabel(
		root, "Torso", "Torso", TORSO_FRAMES.NORMAL,
		UDim2.fromScale(0.50, 0.38),
		UDim2.fromScale(0.50, 0.49),
		2, appearance.torso
	)
	local useWhiteSkin = (appearance.skin ~= Color3.new(1, 1, 1)) and resolvedSheets.HeadWhite ~= nil and resolvedSheets.ArmsWhite ~= nil
	local headSheet = useWhiteSkin and "HeadWhite" or "Head"
	local armsSheet = useWhiteSkin and "ArmsWhite" or "Arms"
	local leftArm = createPartLabel(
		root, "LeftArm", armsSheet, ARM_FRAMES.IDLE,
		UDim2.fromScale(0.38, 0.38),
		UDim2.fromScale(0.09, 0.49),
		3, appearance.skin
	)
	local rightArm = createPartLabel(
		root, "RightArm", armsSheet, ARM_FRAMES.IDLE,
		UDim2.fromScale(0.38, 0.38),
		UDim2.fromScale(0.72, 0.49),
		3, appearance.skin
	)
	local head = createPartLabel(
		root, "Head", headSheet, HEAD_FRAMES.FRONT,
		UDim2.fromScale(0.46, 0.36),
		UDim2.fromScale(0.50, 0.20),
		4, appearance.skin
	)


	local pixelHat = nil
	local hatStyle = nil
	local pixelShades = nil
	local pixelCollar = nil
	local shirtStyle = nil
	local pixelBelt = nil

	local applyCosmetics = true
	if player == LocalPlayer then
		if localCustom.shirt and localCustom.shirt ~= "None" then
			local u = loadDOSEmbedded("dos_cos_shirt_" .. localCustom.shirt:lower() .. ".png", SHIRT_SHEETS[localCustom.shirt])
			if u then
				local img = Instance.new("ImageLabel")
				img.Name = "PixelShirtCollar"
				img.BackgroundTransparency = 1
				img.Image = u
				img.ImageRectSize = Vector2.new(32, 32)
				img.ImageRectOffset = Vector2.new(0, 0)
				img.ScaleType = Enum.ScaleType.Stretch
				img.AnchorPoint = Vector2.new(0.5, 0.5)
				img.Position = UDim2.fromScale(0.50, 0.50)
				img.Size = UDim2.fromScale(0.92, 0.92)
				img.ZIndex = 2
				pcall(function() img.ResampleMode = Enum.ResamplerMode.Pixelated end)
				img.Parent = torso
				pixelCollar = img
				shirtStyle = localCustom.shirt
			end
		end
		if localCustom.pants and localCustom.pants ~= "None" then
			local u = loadDOSEmbedded("dos_cos_pants_" .. localCustom.pants:lower() .. ".png", PANTS_SHEETS[localCustom.pants])
			if u then
				local img = Instance.new("ImageLabel")
				img.Name = "PixelBelt"
				img.BackgroundTransparency = 1
				img.Image = u
				img.ImageRectSize = Vector2.new(32, 32)
				img.ImageRectOffset = Vector2.new(0, 0)
				img.ScaleType = Enum.ScaleType.Stretch
				img.AnchorPoint = Vector2.new(0.5, 0.5)
				img.Position = UDim2.fromScale(0.50, 0.50)
				img.Size = UDim2.fromScale(0.94, 0.94)
				img.ZIndex = 2
				pcall(function() img.ResampleMode = Enum.ResamplerMode.Pixelated end)
				img.Parent = legs
				pixelBelt = img
			end
		end
		if localCustom.shades then
			local u = loadDOSEmbedded("dos_cos_shades_mv.png", COS_SHADES_B64)
			if u then
				local img = Instance.new("ImageLabel")
				img.Name = "PixelShades"
				img.BackgroundTransparency = 1
				img.Image = u
				img.ImageRectSize = Vector2.new(32, 12)
				img.ImageRectOffset = Vector2.new(0, 0)
				img.ScaleType = Enum.ScaleType.Stretch
				img.AnchorPoint = Vector2.new(0.5, 0.5)
				img.Position = UDim2.fromScale(0.531, 0.371)
				img.Size = UDim2.fromScale(0.58, 0.22)
				img.ZIndex = 5
				pcall(function() img.ResampleMode = Enum.ResamplerMode.Pixelated end)
				img.Parent = head
				pixelShades = img
			end
		end
		if localCustom.hat and localCustom.hat ~= "None" then
			local u = loadDOSEmbedded("dos_cos_hat_" .. localCustom.hat:lower() .. ".png", HAT_SHEETS[localCustom.hat])
			if u then
				local img = Instance.new("ImageLabel")
				img.Name = "PixelHat"
				img.BackgroundTransparency = 1
				img.Image = u
				img.ImageColor3 = Color3.new(1, 1, 1)
				img.ImageRectSize = Vector2.new(40, 20)
				img.ImageRectOffset = Vector2.new(0, 0)
				img.ScaleType = Enum.ScaleType.Fit
				img.AnchorPoint = Vector2.new(0.5, 1)
				img.Position = UDim2.fromScale(0.531, 0.20)
				img.Size = UDim2.fromScale(0.76, 0.36)
				img.ZIndex = 5
				pcall(function() img.ResampleMode = Enum.ResamplerMode.Pixelated end)
				img.Parent = head
				pixelHat = img
				hatStyle = localCustom.hat
			end
		end
	elseif player ~= LocalPlayer then
		local cosSeed = (player.UserId ~= 0 and math.abs(player.UserId)) or (#player.Name * 733)
		local cosRng = Random.new(cosSeed + 42)
		-- ~28% of players stay plain/classic with no hat, shades, or extra shirt/pants overlays
		local isPlainPlayer = (cosRng:NextNumber() < 0.28)

		if not isPlainPlayer then
			if character:FindFirstChildOfClass("Shirt") and cosRng:NextNumber() < 0.80 then
				local sStyle = SHIRT_STYLES[cosRng:NextInteger(1, #SHIRT_STYLES)]
				local u = loadDOSEmbedded("dos_cos_shirt_" .. sStyle:lower() .. ".png", SHIRT_SHEETS[sStyle])
				if u then
					local img = Instance.new("ImageLabel")
					img.Name = "PixelShirtCollar"
					img.BackgroundTransparency = 1
					img.Image = u
					img.ImageRectSize = Vector2.new(32, 32)
					img.ImageRectOffset = Vector2.new(0, 0)
					img.ScaleType = Enum.ScaleType.Stretch
					img.AnchorPoint = Vector2.new(0.5, 0.5)
					img.Position = UDim2.fromScale(0.50, 0.50)
					img.Size = UDim2.fromScale(0.92, 0.92)
					img.ZIndex = 2
					pcall(function() img.ResampleMode = Enum.ResamplerMode.Pixelated end)
					img.Parent = torso
					pixelCollar = img
					shirtStyle = sStyle
				end
			end
			if character:FindFirstChildOfClass("Pants") and cosRng:NextNumber() < 0.80 then
				local pStyle = PANTS_STYLES[cosRng:NextInteger(1, #PANTS_STYLES)]
				local u = loadDOSEmbedded("dos_cos_pants_" .. pStyle:lower() .. ".png", PANTS_SHEETS[pStyle])
				if u then
					local img = Instance.new("ImageLabel")
					img.Name = "PixelBelt"
					img.BackgroundTransparency = 1
					img.Image = u
					img.ImageRectSize = Vector2.new(32, 32)
					img.ImageRectOffset = Vector2.new(0, 0)
					img.ScaleType = Enum.ScaleType.Stretch
					img.AnchorPoint = Vector2.new(0.5, 0.5)
					img.Position = UDim2.fromScale(0.50, 0.50)
					img.Size = UDim2.fromScale(0.94, 0.94)
					img.ZIndex = 2
					pcall(function() img.ResampleMode = Enum.ResamplerMode.Pixelated end)
					img.Parent = legs
					pixelBelt = img
				end
			end

			local hatAdded, shadesAdded = false, false
			for _, acc in ipairs(character:GetChildren()) do
				if acc:IsA("Accessory") then
					local handle = acc:FindFirstChild("Handle")
					local accCol = (handle and handle:IsA("BasePart")) and handle.Color or Color3.fromRGB(200, 200, 200)
					local accType = acc.AccessoryType
					local lowerName = acc.Name:lower()

					if not shadesAdded and (accType == Enum.AccessoryType.Face or lowerName:find("glass") or lowerName:find("shades")) then
						shadesAdded = true
						local u = loadDOSEmbedded("dos_cos_shades_mv.png", COS_SHADES_B64)
						if u then
							local img = Instance.new("ImageLabel")
							img.Name = "PixelShades"
							img.BackgroundTransparency = 1
							img.Image = u
							img.ImageRectSize = Vector2.new(32, 12)
							img.ImageRectOffset = Vector2.new(0, 0)
							img.ScaleType = Enum.ScaleType.Stretch
							img.AnchorPoint = Vector2.new(0.5, 0.5)
							img.Position = UDim2.fromScale(0.531, 0.371)
							img.Size = UDim2.fromScale(0.58, 0.22)
							img.ZIndex = 5
							pcall(function() img.ResampleMode = Enum.ResamplerMode.Pixelated end)
							img.Parent = head
							pixelShades = img
						end
					elseif not hatAdded and (accType == Enum.AccessoryType.Hat or accType == Enum.AccessoryType.Hair or lowerName:find("hat") or lowerName:find("cap") or lowerName:find("hair") or lowerName:find("crown") or lowerName:find("beanie")) then
						hatAdded = true
						local styleName = HAT_STYLES[cosRng:NextInteger(1, #HAT_STYLES)]
						if lowerName:find("crown") then styleName = "Crown"
						elseif lowerName:find("wizard") then styleName = "Wizard"
						elseif lowerName:find("viking") then styleName = "Viking"
						elseif lowerName:find("cowboy") then styleName = "Cowboy"
						elseif lowerName:find("mohawk") then styleName = "Mohawk"
						end
						local u = loadDOSEmbedded("dos_cos_hat_" .. styleName:lower() .. ".png", HAT_SHEETS[styleName])
						if u then
							local img = Instance.new("ImageLabel")
							img.Name = "PixelHat"
							img.BackgroundTransparency = 1
							img.Image = u
							img.ImageColor3 = Color3.new(1, 1, 1)
							img.ImageRectSize = Vector2.new(40, 20)
							img.ImageRectOffset = Vector2.new(0, 0)
							img.ScaleType = Enum.ScaleType.Fit
							img.AnchorPoint = Vector2.new(0.5, 1)
							img.Position = UDim2.fromScale(0.531, 0.20)
							img.Size = UDim2.fromScale(0.76, 0.36)
							img.ZIndex = 5
							pcall(function() img.ResampleMode = Enum.ResamplerMode.Pixelated end)
							img.Parent = head
							pixelHat = img
							hatStyle = styleName
						end
					end
				end
			end
		end
	end

	local pixelFace = nil
	local chosenFace = "Classic"
	if player == LocalPlayer then
		chosenFace = localCustom.face or "Classic"
	else
		local fSeed = (player.UserId ~= 0 and math.abs(player.UserId)) or (#player.Name * 521)
		local fRng = Random.new(fSeed + 108)
		if fRng:NextNumber() > 0.30 then
			chosenFace = FACE_STYLES[fRng:NextInteger(2, #FACE_STYLES)]
		end
	end
	if chosenFace ~= "Classic" and FACE_SHEETS[chosenFace] then
		local fu = loadDOSEmbedded("dos_cos_face_" .. chosenFace:lower() .. ".png", FACE_SHEETS[chosenFace])
		if fu then
			local fimg = Instance.new("ImageLabel")
			fimg.Name = "PixelFace"
			fimg.BackgroundTransparency = 1
			fimg.Image = fu
			fimg.ScaleType = Enum.ScaleType.Fit
			fimg.AnchorPoint = Vector2.new(0.5, 0.5)
			fimg.ImageRectSize = Vector2.new(32, 32)
			fimg.ImageRectOffset = Vector2.new(0, 0)
			fimg.Position = UDim2.fromScale(0.531, 0.48)
			fimg.Size = UDim2.fromScale(0.56, 0.56)
			fimg.ZIndex = 4
			pcall(function() fimg.ResampleMode = Enum.ResamplerMode.Pixelated end)
			fimg.Parent = head
			pixelFace = fimg
		end
	end

	local toolIcon = Instance.new("ImageLabel")
	toolIcon.Name = "HeldToolIcon"
	toolIcon.BackgroundTransparency = 1
	toolIcon.BorderSizePixel = 0
	toolIcon.ScaleType = Enum.ScaleType.Fit
	toolIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	toolIcon.Size = UDim2.fromScale(0.30, 0.30)
	toolIcon.Position = UDim2.fromScale(0.84, 0.26)
	toolIcon.ZIndex = 6
	toolIcon.Visible = false
	pcall(function()
		toolIcon.ResampleMode = Enum.ResamplerMode.Pixelated
	end)
	toolIcon.Parent = root

	-- Pixelated ForceField overlay (replaces smooth 3D sphere)
	local ffFrame = Instance.new("Frame")
	ffFrame.Name = "PixelForceField"
	ffFrame.BackgroundColor3 = Color3.fromRGB(0x55, 0xFF, 0xFF)
	ffFrame.BackgroundTransparency = 0.78
	ffFrame.BorderSizePixel = 0
	ffFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	ffFrame.Position = UDim2.fromScale(0.50, 0.50)
	ffFrame.Size = UDim2.fromScale(0.92, 0.94)
	ffFrame.ZIndex = 7
	ffFrame.Visible = false
	ffFrame.Parent = root

	local ffStroke = Instance.new("UIStroke")
	ffStroke.Color = Color3.fromRGB(0x55, 0xFF, 0xFF)
	ffStroke.Thickness = 2
	ffStroke.Parent = ffFrame

	detectSheetDimensions("Head", head)
	detectSheetDimensions("Torso", torso)
	detectSheetDimensions("Arms", leftArm)

	local origDisplayDistanceType = humanoid.DisplayDistanceType
	local origHealthDisplayType = humanoid.HealthDisplayType
	local nameBillboard = nil
	local nameLabel = nil
	local healthBg = nil
	local healthFill = nil

	if CONFIG.ShowPixelNameAndHealth and player ~= LocalPlayer and origDisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None then
		pcall(function()
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end)

		local nbb = Instance.new("BillboardGui")
		nbb.Name = "ESpritesNameTag_" .. player.Name
		nbb.Adornee = hrp
		nbb.Size = UDim2.fromScale(4.8, 1.2)
		nbb.StudsOffset = Vector3.new(0, 4.1, 0)
		nbb.MaxDistance = (humanoid.NameDisplayDistance > 0) and humanoid.NameDisplayDistance or 100
		nbb.AlwaysOnTop = false
		nbb.LightInfluence = 0
		nbb.ResetOnSpawn = false
		nbb.Parent = getBillboardParent()

		local nLbl = Instance.new("TextLabel")
		nLbl.Name = "Username"
		nLbl.BackgroundTransparency = 1
		nLbl.Size = UDim2.fromScale(1, 0.58)
		nLbl.Position = UDim2.fromScale(0, 0)
		nLbl.Text = (humanoid.DisplayName ~= "" and humanoid.DisplayName) or player.DisplayName or player.Name
		nLbl.TextColor3 = Color3.new(1, 1, 1)
		nLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
		nLbl.TextStrokeTransparency = 0
		nLbl.TextScaled = true
		pcall(function()
			nLbl.Font = Enum.Font.Arcade
		end)
		nLbl.Parent = nbb

		local hBg = Instance.new("Frame")
		hBg.Name = "HealthBG"
		hBg.BackgroundColor3 = Color3.fromRGB(0xFF, 0x55, 0x55)
		hBg.BorderColor3 = Color3.new(0, 0, 0)
		hBg.BorderSizePixel = 2
		hBg.AnchorPoint = Vector2.new(0.5, 0)
		hBg.Position = UDim2.fromScale(0.5, 0.65)
		hBg.Size = UDim2.fromScale(0.68, 0.24)
		hBg.Visible = false
		hBg.Parent = nbb

		local hFill = Instance.new("Frame")
		hFill.Name = "HealthFill"
		hFill.BackgroundColor3 = Color3.fromRGB(0x55, 0xFF, 0x55)
		hFill.BorderSizePixel = 0
		hFill.Size = UDim2.fromScale(1, 1)
		hFill.Parent = hBg

		nameBillboard = nbb
		nameLabel = nLbl
		healthBg = hBg
		healthFill = hFill
	end

	playerRigs[player] = {
		player = player,
		billboard = bb,
		nameBillboard = nameBillboard,
		nameLabel = nameLabel,
		healthBg = healthBg,
		healthFill = healthFill,
		origDisplayDistanceType = origDisplayDistanceType,
		origHealthDisplayType = origHealthDisplayType,
		root = root,
		character = character,
		hrp = hrp,
		humanoid = humanoid,
		head = head,
		torso = torso,
		leftArm = leftArm,
		rightArm = rightArm,
		legs = legs,
		legDivider = legDivider,
		toolIcon = toolIcon,
		pixelHat = pixelHat,
		hatStyle = hatStyle,
		pixelFace = pixelFace,
		pixelShades = pixelShades,
		pixelCollar = pixelCollar,
		shirtStyle = shirtStyle,
		pixelBelt = pixelBelt,
		ffFrame = ffFrame,
		headSheet = headSheet,
		armsSheet = armsSheet,
		torsoFillMode = (appearance.torso.mode == "fill"),
		legsFillMode = (appearance.legs.mode == "fill"),
		savedParts = savedParts,
		savedToolState = {},
		styledTool = nil,
		styledToolMode = nil,
		descConn = descConn,
		animTime = 0,
	}
end

local createdAudioEffects = {}
local savedResampleModes = {}

local MOVEMENT_SOUND_NAMES = {
	Running = true,
	Jumping = true,
	Landing = true,
	FreeFalling = true,
	Climbing = true,
	Swimming = true,
	Splash = true,
	Died = true,
}

local function isMovementSound(sound)
	if MOVEMENT_SOUND_NAMES[sound.Name] then
		return true
	end
	local parent = sound.Parent
	if parent and parent:IsA("BasePart") and parent.Name == "HumanoidRootPart" then
		return true
	end
	return false
end

local function applyPixelAudioToSound(sound)
	if not CONFIG.EnablePixelAudio or not sound or not sound:IsA("Sound") then
		return
	end
	if sound:FindFirstChild("ESpritesPixelEQ") then
		return
	end

	local isMove = isMovementSound(sound)

	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name = "ESpritesPixelEQ"
	eq.LowGain = isMove and -4 or -2
	eq.MidGain = isMove and 3 or 1
	eq.HighGain = isMove and -24 or -16
	eq.Priority = 10
	eq.Parent = sound
	table.insert(createdAudioEffects, eq)

	local dist = Instance.new("DistortionSoundEffect")
	dist.Name = "ESpritesPixelDistort"
	dist.Level = isMove and 0.62 or 0.38
	dist.Priority = 11
	dist.Parent = sound
	table.insert(createdAudioEffects, dist)


end

local function styleDialogueElement(inst)
	-- Apply 8-bit/16-bit pixel font & square corners to world/NPC dialogue Billboards
	local bb = inst:FindFirstAncestorWhichIsA("BillboardGui")
	if not bb then return end
	if bb.Name:sub(1, 8) == "ESprites" then return end
	if bb:IsDescendantOf(CoreGui) then return end

	if inst:IsA("TextLabel") or inst:IsA("TextButton") then
		pcall(function() inst.Font = Enum.Font.Arcade end)
	elseif inst:IsA("UICorner") then
		pcall(function() inst.CornerRadius = UDim.new(0, 0) end)
	end
end

local function applyPixelResample(inst)
	if not CONFIG.PixelateSurfaceImages then
		return
	end
	styleDialogueElement(inst)
	if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		if inst:IsDescendantOf(CoreGui) then
			return
		end
		pcall(function()
			if savedResampleModes[inst] == nil then
				savedResampleModes[inst] = inst.ResampleMode
			end
			inst.ResampleMode = Enum.ResamplerMode.Pixelated
		end)
	end
end

local function enableWorldAudioAndImages()
	for _, service in ipairs({ Workspace, SoundService, Players }) do
		for _, desc in ipairs(service:GetDescendants()) do
			if desc:IsA("Sound") then
				applyPixelAudioToSound(desc)
			elseif desc:IsA("ImageLabel") or desc:IsA("ImageButton") or desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("UICorner") then
				applyPixelResample(desc)
			end
		end
	end
end

local function disableWorldAudioAndImages()
	for _, eff in ipairs(createdAudioEffects) do
		if eff and eff.Parent then
			eff:Destroy()
		end
	end
	table.clear(createdAudioEffects)
	for inst, origMode in pairs(savedResampleModes) do
		if inst and inst.Parent then
			pcall(function()
				inst.ResampleMode = origMode
			end)
		end
	end
	table.clear(savedResampleModes)
end

local EXPLOSION_B64 = "iVBORw0KGgoAAAANSUhEUgAAAoAAAABACAYAAACKusa+AAAD0klEQVR42u3dXU7dMBAG0LbqFskiwyLpE0i9KMRJPP6bc55BXI8dX/zJdn79AgAAAAAAAAAAAAAAAAAAAAAAAABa+a0EEOfj7e2j6EF8f/csAtDMHyUAAMhF6gABSpO/2w+uxBCABySAAADJSBHggqNk7zORK07+9sI/uBU+yBJBAC6QAAIAJCM1INRZYlb682e/1/rzX7ZX+kAnieBoSeDs/T9K+yW8QG0SQACAZKwqqSr69Ou3ARycjFxuz96o4YMmgav1/6jtlwgCT0kAAQCS+asEhDpKxLaxP3b107xRdd30/1Ltz14voBkJIABAMvaRNLbqKb+vdkUnYgdJSO36DZ8AntSj9bharf8fj5er9zzevBdy9VPRQBwJIABAMs33AGZbAZYmSa8/N0s9Wp/6HGbv2z5IB3SuR9r+X20cmf98/3Wog+S3LwkgAEAy4QmgFWCSFdLe6e9tMfW6/G7f7Bbrf8x/vv9YnQQQACCZ9vcAJrnn6vapyM3KUHLA9P1/9XTvxXnB/Dep5Pc8vvan+bovCSAAQDJhCeDle7Em39Nz+x6wkzpM095FvY6/r3bXTngmX8kTbPB5Idv85/uvUj2S7uEdpb0SQACAZLwLuPbKZvGVwzDJj3ej/ihqfOj/Qrv5YMX28nB87AfPSZIk8HVv7MfWt70SQACAZCSAoycIkq7/DfLu22+fZx+zHvq/03OL+Y/v96luP/fv6snuVz02ewABAOggLAE8/c//ZGU//Uog+SnR1VQ75VibpCSHbdLPm3T+S//9V1qPRdtbWo/eJIAAAMm03wO4WFLR+p2xvVcOh+2NXvF3Gjfuu8vd/6OPj2Hng0Xb6/uv7nhxmrsvCSAAQDLhCeDhmxQWW9lVf2PENkd7mydBvU3SrugVdtr+L31uk7U/2/zn+48VSAABAJJpvgcw7Urn4imw6evVOAmxgtb/Uz7ve5Jxnm3+M0+pwwQkgAAA2f4RV4JYd0/HzbZCOm3n3SSo85sfhr3/r7BOrcbRqv0f/Zyf1mdbfF5YZP6DGUkAAQCS8S7gYGf3ZFnpPqtrc6Od8tz0/xK2tfvJ/AfjkQACAGRbSCsBEW7vCRt0z9dwewELE6Nh6jV5/9dqf+m9cLO2G5iHBBAAIBmrSkI9PR05WvJx2J6riVbQqdjR6rZa/7euk+QPiCIBBABIxuqSplZJOh7f+/apNAmcLPlbvf8BZicBBABIxqobAlRLCEsfZAkaABdIAAEAkpEaQCDvQgVgRBJAAIBkpAzQgDc+ADASCSAAAAAAAAAAAAAAAAAAAAAAQFf/AC33GuzCsHa3AAAAAElFTkSuQmCC"
local EXPLOSION_FRAMES = 10
local EXPLOSION_CELL = 64

local function resolveExplosionAsset()
	if CONFIG.ExplosionAssetId ~= "rbxassetid://0" and CONFIG.ExplosionAssetId ~= "" then
		return resolveDecalToImage(CONFIG.ExplosionAssetId)
	end
	return loadDOSEmbedded(CONFIG.ExplosionCustomFile, EXPLOSION_B64)
end

local explosionAssetUrl = resolveExplosionAsset()
local activeExplosions = {}
local function spawnPixelExplosion(explosion)
	if not enabled or not CONFIG.ReplaceExplosions or not explosionAssetUrl then
		return
	end
	pcall(function()
		explosion.Visible = false
	end)

	local pos = explosion.Position
	local radius = math.max(4, explosion.BlastRadius)
	local sizeStuds = math.clamp(radius * 2.2, 8, 40)

	local anchor = Instance.new("Attachment")
	anchor.Name = "ESpritesExplosionAnchor"
	anchor.WorldPosition = pos + Vector3.new(0, sizeStuds * 0.35, 0)
	anchor.Parent = Workspace.Terrain

	local bb = Instance.new("BillboardGui")
	bb.Name = "ESpritesExplosion"
	bb.Adornee = anchor
	bb.Size = UDim2.fromScale(sizeStuds, sizeStuds)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Parent = getBillboardParent()

	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Size = UDim2.fromScale(1, 1)
	img.Image = explosionAssetUrl
	img.ImageRectSize = Vector2.new(EXPLOSION_CELL, EXPLOSION_CELL)
	img.ImageRectOffset = Vector2.new(0, 0)
	img.ScaleType = Enum.ScaleType.Fit
	pcall(function()
		img.ResampleMode = Enum.ResamplerMode.Pixelated
	end)
	img.Parent = bb

	activeExplosions[bb] = anchor

	task.spawn(function()
		local frameDelay = 1 / math.max(1, CONFIG.ExplosionFPS)
		for f = 0, EXPLOSION_FRAMES - 1 do
			if not bb.Parent then
				break
			end
			img.ImageRectOffset = Vector2.new(f * EXPLOSION_CELL, 0)
			task.wait(frameDelay)
		end
		activeExplosions[bb] = nil
		if bb and bb.Parent then
			bb:Destroy()
		end
		if anchor and anchor.Parent then
			anchor:Destroy()
		end
	end)
end

local DOS_SURFACE_B64 = {
	Stud = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAhElEQVR42u2Wuw3AIAxEsWdiFfqMRs8q3slpEimKzMcJCc1dafkZDFdcCNBikVVUVTWbiWhk6CteD93rIpJFJH/K1+DrkJSSzuTZ80wxxq37p06eV5sQF2DLKLXmlgGf8mwZyBpywqUU6hnQw5Nn09bhM3kIQh5AHkAeQB5AHkAegH7VDl6DwC2KKvNBAAAAAElFTkSuQmCC",
	Inlet = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAkklEQVR42u2WwQ3AIAwDHUZhBUbrHEzCKszAKumrUkVDIVXVfuxnxDl5JMgA9bNkUFfn+8e8jOCUUj4XY4wbAJRSZKX5Kh9WYABorWUAUFX1Nr/j+wFMuDe5k5cPfy8hB7gMcGyrpVrrNjP08sE6S8vkgEVEZv+KhzfNRqc2af4aT1HMA8wDzAPMA8wDzAPUp9oBeMl8C8RZUuUAAAAASUVORK5CYII=",
	Universal = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABAElEQVR42u1XwQ2EMAxzGIUVyir8bwfmYIf7d5XOwCq9V09V5aBERQKJ5oNUoTgxIXaBjljXNePVcQUDwg5zzjSxiIgxb7biiQbegqWUvgCwLMunZiDGKAw8hLDXh/M8bwDQvj9ZwGvgmnYrOAAcx7EzdicPzXX32gww8LaI0wI8QRhwx3T3X/A8Bsq0WzpmDJRpZ5FS2k4LKAPIiihgddeEAdGKKODtkIvn27aAyh64YpG9SAv+Se563s/A8AO9et7rJ0QDt+g52wMeP8FWsUvPreCan6Ba4NFzNgMePzH8wDMZ8Og5Y8DjJ1gBLj1vGfD6ie6LieYHrH5iaMEj4gdFb933ie/RyQAAAABJRU5ErkJggg==",
	Glue = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABgElEQVR42s2WW66DMAxEB6tbdBZpL9L3I8QNxCa3ClRFQipMJw/KnA7M2AD4+e3rrd401KNAi6IdLIxtU5ix39OiAAugpdM/8CsDWlx/uRKY+2s3Q33yo975WcCso79o9bfxlUGhOZq86GHldTGnyVmqnk5+2pwWkBnnZha4HpgBVL0tpn8y+3gHf7I5E66nGdfPIn7tushb774/+HfvQe/Gc/8+ni8gMgvDDjqPiwn1brxBPy0GLRqRuU2QmQedkevB5kTE8CMc4PRtHXJ+ynHIiS6KM05QGJXwbS2TKGISxZgztGJui3lDKo7iFWdoNceuR09GC2acwQ05Dt/+lBMjZ5ZznEJq4ETMmcUcI4fUJScaZ363Dxxy/AEnwr6Q+2n5L7X3R2macIYuzZ7j5yBFqzle7Qu4IcerfWE5x6t9YTHHq33hN/vAjb0/9e+cobH343+9/6bqTk/3/hln6OneP+MMbVtubr9hZnY9gZTryeZYGPhC759x5uHeP+HMHwXBz9Rywd5VAAAAAElFTkSuQmCC",
	Weld = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAArElEQVR42u2WQQ7EIAhFKfGKcEg4ZLtq40wqIk3Lhr/T8ASMwb8R0Q6JagAAIhKCmRme8q3fUFUTIKIrhpmBiOApjz18djSSFRPlsV+IyLQL67ojPN5dk9XBTKs8eh+MqpqHR3nMTO4q4M3k0wLeTm4W8EXynwL64BFsHRjlbwfRKJF3EK3w6B0y3kG0yrf/jyWqKL9lf8cIySo/UH6g/ED5gfID5QfKD6T7gQNSqupcy0wqAwAAAABJRU5ErkJggg==",
}
local DOS_MATERIAL_B64 = {
	Brick = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAA60lEQVR42u1WWw7EIAhE4hXxkHBI96fpan2Adq0fW5OmaTozGGUmOGaOsHF5AAASmRYQolt8fwolIkSUfXcXUcFvQ0tdTH/WNtMSsi5NF2eK/hKLO4qmWNxRNMMyc4xEEQCmnrt8tzsH3LH7ZT7X+F71f8Pn5qxQcgKfaLquDWXgeFdsEFcnnYbF1f7XTtCH798qiY93yJXMRav81IbvPDB6l4X/Oz63ZAU+0ek9LD7R6T1dXJ10mi6uTjoNezZhsJ2v3efGa3vnAa92+IQbMv9r88DfT8W4ZRS/XsHOqchr/ueRnKj4v8sXgQ92ZAUtOEGdWgAAAABJRU5ErkJggg==",
	Cobblestone = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAoUlEQVR42u2XQQrEIAxFfwav+HNIPeTMomTXKTWJSGmyKzT6EPK+CskvNlYDgN77VJOIgCRIujdWVZA8AABgjOFayNtn9cHmKoACKIAWaVbVvQARE4YA7qrbdHv2v+m82cfM5h79/utpWUe5PA3tyJZNQTTVSkQF8J4syPB/CCDbBUsBLAvSwyhTWjUFz76SzbwlLwFmLiQeD1xNgux+nv8AmeAsZx7GQsoAAAAASUVORK5CYII=",
	Concrete = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAB4ElEQVR42qVX0RXDIAgktts4D87TeWSfrJN+kYfkEG39MtEgwt1Bjt77xcwkImSHf6fPIkK9d2qtETMTGvZbEQn3EREV3eQdaK3dBnTYw3vvoVHvuD3Dn1MiL3vvxMyDAX8zdGC0xszQ6YOZL3/IP8M6mqWKiKjsHI5CiPKPMIT2EBEVG6IVo3buQ4xsqCN2zTr2nh08Q/IMA7Mb+/Eiok+tddhcayV9Z+e6fp7n/Xye531Lu88P+43uFZExAgjhO+nZAelAQ5QvDyZ1SvVhJj5ZOixuyuy2HnxKLXQbXUPfe7zYCx6RFO8OJFIzqVZ9KAjtM2ciqtnU+EggfRgisAKWbM0angmQLWgiQi9m/qDNllKeYrXWgY425K01SEcfZf12GgGr5RY8O3jJ9h/XdV0ePBoelMOsuOwWrmLBE9FmpRD9svZgAUJ51N1EEYpYEkWt2EYhKjjeuDcYVbqV4lVQDUAlFPUFSJ4zZ7zdAYT/oHm1ofHS/V6lVHTLlYqJChyshjtdbtSg7tgTkacQWZm089XQ7wpVQWFcabcihuxGo6CmI+sPkCNRo5Kl4sECW9GQLmQUzei8RMOdH5RMLzJdCath9tfzS2VMQbhDQc37TieN3pVVBYzSlNURNLfPX0AcKVO1q7BMAAAAAElFTkSuQmCC",
	CorrodedMetal = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACw0lEQVR42p1X0ZGlMAwT3HZDPUo9e+3E/dAO95E4UYID7x0zO/sIwXYsWTZbJi4AMBAAYGYgCcLaGoB2TxhgAIh+Xy+9999vNvbyu7+YWTaCGcvLnbMbT4bB4RCY2fB6MsBIgBkbyWuOcPTVT6QGM3HbO9sgDMnKoeYM+bX7xpVzq091LQfpnwM1K++6c8/ocBAQ+4yZGvO06roGND/Xy6E0lFTDUuOWw14ywLwkCslbxBqgplafRbCpDWPnz+4E0cjc8XB68kamFWR6qGI3wUCklHq2LAEAtkxcujn6fWP1tCfiz/C8Bu/kVcj3ZAjreHZaN9zKU53o2hBUPa0715L9Q/KXJI7zLw6c7aWDv7CzbDxxlL/jwHmeIevP8wRhOHB2rM1wHAcOnDhR/vsBqkVsOefLMWoqSLao5xS3rDAPnPgEstszF6IZS1dCD0jT+CRUStRPA9pIXkqOeUNnbZfglUKGjmtQK6HbAFzKzFWq3IgS0siYrJq9Cm9UITBgz8SgTO5oVVoqJl5aw3pQ/8veQpQydGWam0xTQkshppl9j5ezWXGsh3IJVhveK1o3VOItSaYkfSGeHmbmi0L2ozgvZbXiaRa0bEv9jhmwLt0IiDo0OrJIsffsuXc/sXvV//XE7uTJxgbgIvnVQBL1gTZFBXoxw+iBEYafcmIb0vfthKRwvGWuDCkG1PVddXslMpqheYZcBRXNE9FQc5sJ3+T22wy9texdxUdrd26r2nKfAkqSIQZKqZowVMHA1oWEfkJIZf9ThYQQPOHZGlLOg/AM3wWMJ6uuEekGz6iEX45b2pBeg5/Xa5Z/1FgCIPbuJVTlNVndyM8IGQ4vVl5vQ6kOH58OpK6c83flfKi8+I4My3CZbv+ymfD/H8keBhKfCQeiLAgz9voYfyejmSHnHFZTm8CsQvBmLPoEj9rupyWrtv8BzMuPZwRw59cAAAAASUVORK5CYII=",
	DiamondPlate = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAdUlEQVR42u1WQQ7AIAhD/tg+kk9uNw/boobM4KEchWJjbNMWEZcVlltxdQIAlkFfs1l8J0ByaQkAI/k6z+L92RgtGc1k8b77glnPdz/xDN8kwyMJ/KnzGb78E54jw3IjqrJi+YDygPKA8oB8QHlAeUB5oNwHbtqRvz13TGzBAAAAAElFTkSuQmCC",
	Fabric = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAT0lEQVR42u3SsQ3AMAwDwU92pIfUknIRIEYWsIu8GoFgJeFIuqH61L6gmgIGazbmO8mn3J2fDxy4/M0a0IAGNKABDWhAAxrQgAY0oIHfG5gEsRXudW+/qQAAAABJRU5ErkJggg==",
	Foil = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACd0lEQVR42q1X27HdIAxcn+NuqEfUY9qBftSO8pGIyHsRdmbiH3sWSejFCh9mZgAwxsAYAyICABARjDHgayIy1xjP5DN8jIHe+2+8924iYr13672bmc1vEZlrjjsWH193WV9f2Yw6ImIf9zJGFyPuvf/AGWOduMYZ8cexkxXceBSMxjmlAH445I/L11pvm9ZaZwlOAFMgeulCtdalIX/ckDvGtWeH/O22jt67vWoWknEju40z3Sh/mJlFT7PujRGvSrTqlafTUWvF+aTghiPukUeHOYgsAM7QyQpeG+6J1QbcP9FOlI/Z4X6bJfjfhMPNmcl/nlIXI9tlYhUxn4SlfMZQzGKR6XbsxkyaMaxjYIrdKTAFR8pdBZBRdbSPN55mG7gD8f12Y9c//nzcmo4JJ2uuFYs+ERrzzbkyFLn6zYxY8QHj2Sk4zMyYWN4cM54FMUMeAGdhNW9us2AXQcwQZ2THjE+BHX4jimnK+oAHzIrpngiNx/TRe7cdc7ECk9W/XMV4FAPA54nzObos1Rx1rTVlwIh9eICwQoyGja+acWcnlszxD+iJnkZlPoZRntccyxyK+JKInm5EfMHk1MYa74YcAGDH+RmVOraSe6JeHlpYDZndxNsNrejE6j+C/xdExL4ALhFBKeV26y2lQFUhIlBVqCpaaxARXNc110spaK3Nt5dMVW+EVUoBgIm77dOpM6sZ13x318t+YFZ95di3lHJ5JKWUW8QxE/6OuMvHyCIeI3XdiI8x/jbh25tMJs+1f3NTMjP7ZEcpI6h4u2XG5HMfS5Qx41dVL1Wdabyua6a81rosjareLp6llLkxy7fWZurZTmsNvwBDFyOZBH4CDAAAAABJRU5ErkJggg==",
	Glass = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAx0lEQVR42sWXQRKEIAwEh/0j+0h85Oxlc6AIiIYkuZjDlI12SbCQJBLrAwDluvD9X7VeapXReqlZBgBAkpUkWiNaG3qpVUbrpe4yYBJc7o9Z0BvevYEM+FRBFFxVEAkfFETDuwVkwDsFGfDlVxAB39qIvOHLjcj9yZ8qOA1/pMADXncVeMG3FHjCbxV4w5cKIuBTBVFwVUEkfFAQDVenYSR8WEA0vL6ZBSfhpnF8Av56HJ+CmxVY4eYTkRVuOhGdgIuCkv17/gOVCG4K1l8KxgAAAABJRU5ErkJggg==",
	Granite = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACj0lEQVR42p1X7ZHrMAhEvnSjeqR67Hagnqgd3S+49R748p5mMk5kic9lIU1V9xhDzExERMxMzEz23vEdF54dY8SdMYaMMaS1Jqoqc854708/i+tLRE5/sdYKYXPOuHCep6y1QtB1XdJ7l957/Mbl+77WWvFBQ3rv8kIPcO29pbUme+/wBg1DQap6i457qappFDEqh1/Gg3jBFZiZtNZCMBo+5xQzC+MwNVmq0Ig2xggM8BO9yPLHAh07GCU3VkR+RS8MkGSh52jQk0eVxwxIlNXGGDvDQLZUNVDuKUPBjBFWlq2DywTxwPuttVuaKq84ApgGNvqoXuClTxS5gVwZnntOj597ZWSBQvGJhnm4nXQqsPq7TLaISFPVzV45o7FRrNQjgso/zb2fOfgghiurDMYA5zerhuq7mf2AkAVlBMWIz7BTGczkFiBk0snC7p+MLZ94IAMkl2swIfI9liF6+MQXVd4rdnSMBRNiyJG5mBUzhQ7KfwHhjYgcfNxs0GLm8excBdwqPbcUZDX6KUVnkeKoYe5Rx6sCS0bJaAxipkpL1j0RW3tvaSKyK6rFeude/3S+4g9On5n9MCF7+kRGjOr/qY7AAEcA0+GtN+sJmRJ2IJsPeL2QBREgWIpVXiuGy6Znl80O3ZpRNpox4LIxnZVnNF6l6/ir+VTTLCrmimithcfZtH0jIlWNPyHYYjHkmfe4X3W9bLGOX/PAJyXEec6MzDCQ8Un0ggwglTEVFuacEWIEXTbGuUFH1nKzUPLMUEWE5z9W7u/d0IPzgwcrJVWj+YuAsMK88X293+/zui4ZY0jvXdZa0nuP377n+9kUxKDlP6d+bq0lqnrT0fbe+8mTDGw4CVeRqvCDd8xMvgFUF0FuWLkS4AAAAABJRU5ErkJggg==",
	Grass = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACQElEQVR42p1XW7LrMAhTOmeLeJFmkb4fCQkGQTK3nU7zIBgLkAhknV9M3D87v6+juWe/YMP8TsF2fQoW/E1zlJwHx34xFpTZTHn8soCAKwD/IHMWI2eBxWt+4Q7FH4qPqt7HQ9z5eGxEJNmajc7nnogA87G/bVTxiw7sWERuo+0z94XtePufweeheYeXn5/fjXeoqjlqAFNJUB45spisK7ihCeXjys8dgIcIcw9uc+oCk6EYgvK+f1ZEIEOh8/IZi8sXnL/ur5lNLMDqua59/yy6qWfhDCiEFJZPzxBAPhTvWYwBuaFQ2fND22wni3BOdm42lZ/Y0s9zhEAYrIz1KlgZn1DeANaBicUK5i48V4yxY9g5K9iWMzbYgJIJ43FJ0w6hqqAtractyU9VuT5/sRa6NJhtzL8sWWBcXXF8lVu/QCdmDFGU4gIkuP0OqgC/BOyPf4nHHX16dhORxHabbgQajhRuPBIL9rh2m5z5hyj3jzPItuIPpTbRZwlvpeWsSLu+Z91g/z9TPIOXIeBFyUPt6blCAcAjPISqkxxHQz3yIlO4BvhaStI+shxjXkTkKbajYT8PdhT71oZbWttexTu3+1YtWxSNLDOWK3uXiFBWtw+iBHA1rBSPjdYVKfmK98xoI3oKKi7WTTrdGP4KdSH3oHM8vuW1o2HbfUQq/4ppiMFezYlfxKySe7xCNrMoVePX22KUDbvZrRq/qpfXCqmONw5ZspKqFe8A/zui0al52AvLx6mGEVUaLioUmoL9B4QlE4SSoaONAAAAAElFTkSuQmCC",
	Ice = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABwElEQVR42p1XW7bDIAicuEddJFkk9+NqQpCXzTn9sEB5ODMlYGbu4gOi99y/Z5529vzFmVU8O/5XZ2YCMKCeAYDeo/YxY6RNxXsxTea67/uTfJ1X4GPf6wOmXSaX/gBwTbss6OrMHFUedartXudWzGqiyerHAIhUN8Kuu5WT0Mk9f/28ExDBssLKc+KvJ9ae6oKxRd3QvFs5ec9fY2kAuP6pEtxp1k0RM9737e57NxnSZXIZbyE9xNIQGEh5XeC5FeP+7jQ2j+cW0jOeWzoxLLuIv5iZT9Be4Xk4ARXfBmq8XcmJ6szYVNbQidIEdOcneIm+pzUBCnj/dEMx0jMsaZ2gRwcCFmR3XtIMQyekajYL6RHPLaRHPNfx/n+BrvAA7SjsE97Emot8KjKjsE9EKuvuAyd7wC+b0GcjsoI9pFvdePtERWXfndC58/IuaOhENkUAaBbPvd0v7MbQiYrKbvsADhUuQntpAhHPtWpRgecyaUlltQ6UMXCAdpcxCwMZz01NpxozXJWdZ/fNKLvzk90xUs1mTdPtxtCJjOfZeVNCHKL91/eBISdQqpZsZmRIt65Iqqy5D3wCimg/fR9Ytj/niAgNLww4kQAAAABJRU5ErkJggg==",
	Marble = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAfklEQVR42u2WMQrAMAwD/Ul9Up9Uh0LbkITSxRoqryGcCbZypUeRFACR1K7ezr7eLyf8asAFl6RywiWpnHCS5wu44ADuIXTASa4b6IIPa+iATw10w6cg6oYPQeSAX0Hkgi+HsPtvKCd8u4ad8VzxgfhAfCA+EB+ID8QHfu8DB3X1shOtQJ6GAAAAAElFTkSuQmCC",
	Metal = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAUUlEQVR42u3UsQ0AMQxCURzdil7SDOmrMgNFPhUlEtKrmVkFU7sbHXAkybZsK9ErfcFROPEB3/0jNqC7374AB3AAB3AAB3AAB3AAB3AAB+IO/BSg030/y8ruAAAAAElFTkSuQmCC",
	Pebble = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAy0lEQVR42u1XQQ6EMAikxC/CI8sj3dMaqymLgGFj7EkyghSZCTQiWqHwLNYXiWiwRWTEYbQFyBQXvw+9d/XjxwT2NoEA9VVNaBZ/S4CZ1UyPNz7h3FR8Fh+h+KDntr+qxbr7EL9ZWXBXE7ZqGpb3wBItodV/9gsxymOLv6YjGOWx1X/GrP/UgSs89vjvq7nRsKoJXx0w60AYj+hAGM/QgTD+KB0I4x4duKsJXx1I2wu8Up2yF0TmhbS9wDsvPHMvuDIvpO0F3iYs14EPqamhOvMTBAYAAAAASUVORK5CYII=",
	Sand = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACAElEQVR42qVXQZLEIAhE/4iPxEf2HhwniEB0h6pU1KCiNA0hYQLAABizLUyw4/rbEFY6CMbzNQEG2QlZ347Pze2Yt1H0VCIiFiYioSmjP2Uf761Tb/3TLqbfScu6Fm16BQCIGsUiFH3vrRMLh29P10odi8t22mdicS0nku+C9u3JNMzeVgEYyfFDy6PxU/nO91C6IhZOFJwh/ER/uYH1VEK9latT2lsZfQQYGutX7fvppyGNWPDpi4NwcTaHg6MI4I1YeGBg9+dA/q2fb/Snbo2sGyiHG8MZ0qNoinTrfvV7CMb8oNviXrte1z1Azu2c8L8fOV4ExTnlkwvsRnFuwMb9NgS959HZDQqoWFwE34JMu1eHo6bs6m0yxpoDHIS+9JLR1LdcoKk7oGJZrH3j+Thp2XC2OqINEMqz4nl2vHEPRTnAQ+8d5+MgCrBGgVfpZBGwV0u4rogoKq9sPGdGxCEbGfPcTLXZyRYbK+LbK04eDLSFHZ9QpCXLHoJQ1ILt3yD1pEYcr0unlR88HhAnf4iLfju36vw/FEqSlMRc5Tr3xFjrWrceWNmMNzfYSimPf98liwH0o3hMt+cC38ACAONEULSJLaf/UgFH/xKmHkCat6P3GeEg/I0rwoTodG+JyK+CL2/KFgtZ/X/WRlqApH/H+V+wP65zwLsLVooWJvwB8bpPpJfjAgkAAAAASUVORK5CYII=",
	Slate = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAm0lEQVR42u3XQQoDIQyF4b9Or/ju0/PofXKddlNKB2oZmCEvCwU3JmgWfhHpvT+B3ZSUtnZ7F2Ab9zHGNCiJf/ErctssATi04dnc5jp4V4Dj4O9hE1BbQYaAnwqy70NzCgBobgE4BdRVkCVgteJPAU4BOAXUVJApYLVigA14HNksIogIrs7FKUBSMQXZAlYrnv6MMl9InAJKvAUvT8632jua+T4AAAAASUVORK5CYII=",
	Wood = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAaklEQVR42u2VMQ7AIAwDDX+ERzaPbKcOVGlZsMpwnpDMkCgnu0g6j6ZX9ZCcfr0f7euX0a/6WfsMED2Guz3l8lMGsnO5fBhIGcjk8vfMgckyS/10gMkyS30YIAfoAhggB+gCGCAH6AIYuAB2lImO2ySuKQAAAABJRU5ErkJggg==",
	WoodPlanks = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAjUlEQVR42u3XSw6AIAxF0VvjFnWRZZF1okaJxk8HMHgdEcIjEJIDGBA0rBEgYvo9gVlJ5UeAMpfULjL5gQ4qgHD32NsTe/uuz91PfVv+TfY43tYBv2sukMk3P4LmCzA5IAeuHHjjQe1GnX/yQA7IATnQrwNf7/O798GTB3JADsiBvhzI3OfZf4UcaL6ABQkK6yzvNSZDAAAAAElFTkSuQmCC",
}
local DOS_TINT_MATERIALS = {
	Cobblestone = true, Concrete = true, DiamondPlate = true, Foil = true,
	Granite = true, Marble = true, Metal = true, Pebble = true, Slate = true,
}
local dosSurfaceUrls = {}
for name, b64 in pairs(DOS_SURFACE_B64) do
	dosSurfaceUrls[name] = loadDOSEmbedded("dos_surf_" .. name:lower() .. ".png", b64)
end
local dosMaterialUrls = {}
for name, b64 in pairs(DOS_MATERIAL_B64) do
	dosMaterialUrls[name] = loadDOSEmbedded("dos_mat_" .. name:lower() .. ".png", b64)
end

local DOS_FACE_MAP = {
	{ enum = Enum.NormalId.Top,    prop = "TopSurface" },
	{ enum = Enum.NormalId.Bottom, prop = "BottomSurface" },
	{ enum = Enum.NormalId.Left,   prop = "LeftSurface" },
	{ enum = Enum.NormalId.Right,  prop = "RightSurface" },
	{ enum = Enum.NormalId.Front,  prop = "FrontSurface" },
	{ enum = Enum.NormalId.Back,   prop = "BackSurface" },
}
local DOS_SURF_NAMES = {
	[Enum.SurfaceType.Studs]     = "Stud",
	[Enum.SurfaceType.Inlet]     = "Inlet",
	[Enum.SurfaceType.Universal] = "Universal",
	[Enum.SurfaceType.Glue]      = "Glue",
	[Enum.SurfaceType.Weld]      = "Weld",
}

local dosSavedParts = {}
local dosPartConns = {}
local dosUpdating = {}

local function isDOSCharacterPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model) ~= nil
end

local function clearDOSTexturesByTag(part, tagName, faceFilter)
	for _, ch in ipairs(part:GetChildren()) do
		if ch:IsA("Texture") and ch.Name == tagName then
			if not faceFilter or ch.Face == faceFilter then
				ch:Destroy()
			end
		end
	end
end

local function getMeshFaceScale(part, faceEnum)
	local mesh = part:FindFirstChildOfClass("SpecialMesh") or part:FindFirstChildOfClass("BlockMesh")
	if not mesh then
		return 1, 1
	end
	local s = mesh.Scale
	if faceEnum == Enum.NormalId.Top or faceEnum == Enum.NormalId.Bottom then
		return math.max(0.05, math.abs(s.X)), math.max(0.05, math.abs(s.Z))
	elseif faceEnum == Enum.NormalId.Left or faceEnum == Enum.NormalId.Right then
		return math.max(0.05, math.abs(s.Z)), math.max(0.05, math.abs(s.Y))
	else
		return math.max(0.05, math.abs(s.X)), math.max(0.05, math.abs(s.Y))
	end
end

local function makeDOSTexture(part, tagName, faceEnum, url, tileStuds, color3, transparency, zIdx)
	local su, sv = getMeshFaceScale(part, faceEnum)
	local tex = Instance.new("Texture")
	tex.Name = tagName
	tex.Face = faceEnum
	tex.Texture = url
	tex.StudsPerTileU = tileStuds / su
	tex.StudsPerTileV = tileStuds / sv
	tex.Color3 = color3
	tex.Transparency = transparency
	tex.ZIndex = zIdx
	tex.Parent = part
	return tex
end

local function applyDOSMaterialToPart(part, matEnum)
	clearDOSTexturesByTag(part, "DOSMatTex", nil)
	if not CONFIG.ApplyDOSMaterials or part.Transparency >= 0.95 then return end
	local MAT_ALIAS = {
		Asphalt = "Concrete",
		Pavement = "Concrete",
		Ground = "Concrete",
		Basalt = "Slate",
		Rock = "Slate",
		CrackedLava = "Slate",
		Sandstone = "Sand",
		Limestone = "Concrete",
		Mud = "Concrete",
		Snow = "Marble",
		Glacier = "Ice",
		LeafyGrass = "Grass",
		Salt = "Concrete",
	}
	local matName = MAT_ALIAS[matEnum.Name] or matEnum.Name
	local url = dosMaterialUrls[matName]
	if not url then return end

	dosSavedParts[part] = dosSavedParts[part] or {}
	dosSavedParts[part].Material = matEnum
	dosUpdating[part] = true
	pcall(function()
		part.Material = Enum.Material.SmoothPlastic
	end)
	dosUpdating[part] = nil

	local function posterizeColor(c)
	if not CONFIG.EnablePosterization then return c end
	local r = math.floor(c.R * 3 + 0.5) / 3
	local g = math.floor(c.G * 3 + 0.5) / 3
	local b = math.floor(c.B * 3 + 0.5) / 3
	return Color3.new(math.max(0.28, r), math.max(0.28, g), math.max(0.28, b))
end
local tint = DOS_TINT_MATERIALS[matName] and posterizeColor(part.Color) or Color3.new(1, 1, 1)
	for _, f in ipairs(DOS_FACE_MAP) do
		makeDOSTexture(part, "DOSMatTex", f.enum, url, CONFIG.DOSMaterialTileStuds, tint, 0, 0)
	end
end

local function applyDOSSurfaceToFace(part, faceInfo, surfType)
	clearDOSTexturesByTag(part, "DOSSurfTex", faceInfo.enum)
	if not CONFIG.ApplyDOSSurfaces or part.Transparency >= 0.95 then return end
	local surfName = DOS_SURF_NAMES[surfType]
	local url = surfName and dosSurfaceUrls[surfName]
	if not url then return end

	dosSavedParts[part] = dosSavedParts[part] or {}
	dosSavedParts[part][faceInfo.prop] = surfType
	dosUpdating[part] = true
	pcall(function()
		part[faceInfo.prop] = Enum.SurfaceType.Smooth
	end)
	dosUpdating[part] = nil

	local tint = Color3.new(1, 1, 1)
	makeDOSTexture(part, "DOSSurfTex", faceInfo.enum, url, CONFIG.DOSSurfaceTileStuds, tint, 0.08, 1)
end

local function isCustomMeshPart(part)
	if part:IsA("MeshPart") then
		return true
	end
	local sm = part:FindFirstChildOfClass("SpecialMesh")
	if sm and (sm.MeshType == Enum.MeshType.FileMesh or sm.MeshId ~= "") then
		return true
	end
	return false
end

local function hookDOSPart(part)
	if not enabled or not CONFIG.EnableDOSWorldTextures then return end
	if not part or not part:IsA("BasePart") or part:IsA("Terrain") or isDOSCharacterPart(part) or isCustomMeshPart(part) then
		return
	end
	if dosPartConns[part] then return end

	local conns = {}
	dosPartConns[part] = conns

	applyDOSMaterialToPart(part, part.Material)
	for _, f in ipairs(DOS_FACE_MAP) do
		applyDOSSurfaceToFace(part, f, part[f.prop])
	end

	-- Live-update when BTools changes Material, Color, or Surfaces
	table.insert(conns, part:GetPropertyChangedSignal("Material"):Connect(function()
		if enabled and not dosUpdating[part] then
			applyDOSMaterialToPart(part, part.Material)
		end
	end))
	for _, f in ipairs(DOS_FACE_MAP) do
		table.insert(conns, part:GetPropertyChangedSignal(f.prop):Connect(function()
			if enabled and not dosUpdating[part] then
				applyDOSSurfaceToFace(part, f, part[f.prop])
			end
		end))
	end
	table.insert(conns, part:GetPropertyChangedSignal("Transparency"):Connect(function()
		if not enabled then return end
		if part.Transparency >= 0.95 then
			clearDOSTexturesByTag(part, "DOSMatTex", nil)
			clearDOSTexturesByTag(part, "DOSSurfTex", nil)
		else
			local savedMat = (dosSavedParts[part] and dosSavedParts[part].Material) or part.Material
			applyDOSMaterialToPart(part, savedMat)
			for _, f in ipairs(DOS_FACE_MAP) do
				local savedSurf = (dosSavedParts[part] and dosSavedParts[part][f.prop]) or part[f.prop]
				applyDOSSurfaceToFace(part, f, savedSurf)
			end
		end
	end))
	table.insert(conns, part:GetPropertyChangedSignal("Color"):Connect(function()
		if not enabled then return end
		local savedMat = dosSavedParts[part] and dosSavedParts[part].Material
		local matName = savedMat and savedMat.Name or ""
		for _, ch in ipairs(part:GetChildren()) do
			if ch:IsA("Texture") then
				if ch.Name == "DOSMatTex" and DOS_TINT_MATERIALS[matName] then
					ch.Color3 = part.Color
				elseif ch.Name == "DOSSurfTex" then
					local isGlue = (ch.Texture == dosSurfaceUrls.Glue)
					if not isGlue then
						ch.Color3 = part.Color
					end
				end
			end
		end
	end))
end

local function enableDOSWorldTextures()
	if not CONFIG.EnableDOSWorldTextures then return end
	task.spawn(function()
		local count = 0
		for _, desc in ipairs(Workspace:GetDescendants()) do
			if not enabled then return end
			if desc:IsA("BasePart") then
				hookDOSPart(desc)
				count += 1
				if count % 150 == 0 then task.wait() end
			end
		end
	end)
end

local function disableDOSWorldTextures()
	for part, conns in pairs(dosPartConns) do
		for _, c in ipairs(conns) do
			if c and c.Connected then c:Disconnect() end
		end
		if part and part.Parent then
			clearDOSTexturesByTag(part, "DOSMatTex", nil)
			clearDOSTexturesByTag(part, "DOSSurfTex", nil)
		end
	end
	table.clear(dosPartConns)
	for part, record in pairs(dosSavedParts) do
		if part and part.Parent then
			dosUpdating[part] = true
			for prop, val in pairs(record) do
				pcall(function() part[prop] = val end)
			end
			dosUpdating[part] = nil
		end
	end
	table.clear(dosSavedParts)
end


local SKY_DAY_SIDE_B64 = "iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAMAAADDpiTIAAADAFBMVEUoffBLoPrX6P////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAd7zA/AAADtklEQVR42u3dwQ2AIBBFQQz992ysgIMgrH9eCbtzIDFIuxRdMwIABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAgAAIwBAAAgAASAABIAAEAACQAAIAAEgAH5bHwQAAAAAAAAAAOQtPwECAAAAAAAAAFh8JgIAAAAAAAAAsPxMCAAAAAAAAACgzAAAQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAeHLREgAAAAAAAADyALhoCQAAAAAAAABZAPqkrAEAASAAVAdAX5B1ACAABIAcAgWAABAAOheAABAAAkAACAABIAAEgAAQAAJAAGjczo9oAAAgAASAai1/FgQAABAAAkD1Fj8DAQAACAABoLrLfwMBAAAEgACQQ6AAEAACQDkBAIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAAfBFHqAEAAAAAAAAgCwAHqIGAAAAAAAAgDwAu36gDAAAAAAAAAAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAAMAIABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAgAAIwBAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAAAwAgAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAA0JHdWYIhPYi6dWEAAAAASUVORK5CYII="
local SKY_DAY_TOP_B64 = "iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAMAAADDpiTIAAADAFBMVEUoffBLoPrX6P////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAd7zA/AAADXUlEQVR42u3SQREAAAzCMPBvmvc0LJXQS6rXxQIABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAgAACwAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAAsAEAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAAALAAAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAAwAIABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAgAACwAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIBuA0VEAD0WGWR9AAAAAElFTkSuQmCC"
local SKY_DAY_BOT_B64 = "iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAMAAADDpiTIAAADAFBMVEUoffBLoPrX6P////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAd7zA/AAADXUlEQVR42u3SQREAAAzCMPBvmvc0LJXQS6rXxQIABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAgAACwAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAAsAEAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAAALAAAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAAwAIABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAgAACwAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIAAEAACQAAIAAEgAASAABAAAkAACAABIAAEgAAQAAJAAAgAASAABIBuA0VEAD0WGWR9AAAAAElFTkSuQmCC"
local SKY_NIGHT_B64 = "iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAYAAAD0eNT6AAAIs0lEQVR42u3dW1LbQBRF0XszR42SQZ58GKqohIfBktWtXmsElIqQ7WO11FWVAgCW8sclAAABAAAIAABAAAAwvCSVuL0LAQAA/KPLKQAW+URUVdXdLgaABQAALAAAPJFlCgsAAGABAAAsAACAAAAABAAAIAAAGJsnFQoAAOAkTgEAgAUAABAAAIAAAAAEAAAgAAAAAQAACAAAQADAlDzBDBAAAMC0PAkQACwAAIAAAIDBuTdHAAAAd3IPAABYAAAAAQAACAAAQAAAwO6SrZLNhRAAAMDenAIAAAsAACAAAAABAAAIAABAAAAAAgAAEAAAgAAAAAQAACAAAAABAAAIAABAAAAAAgAAEAAAgAAAAAQAAAgAAEAAAAACAAAQAACAAAAABAAAIABgUslWyeZCAAIAAJhfV1VcBgCwAAAAAgAAEAAAgAAAAAQAACAAAAABAAAIAABAAAAAAgAAEAAAgAAAgHskqcRrbwQAAOBtgADwlbf1oLstAACABQAAsAAAAAKAS3JXLcDcfw8FAAAsyD0APKmQt9svXL+4GAAWAADAAgAAWAAAAAEAAAgAAEAAAAACAAAQAACAAAAAAQAACAAAQAAAAAIAABAAAIAAAAAEAAAgAAAAAQAACAAAQAAAAAIAABAAAIAAAAAEABwkSSVxIQABAADMp6vKxxkAsAAAAAIAABAAAIAAAAAEAAAgAAAAAQAACAAAQAAAAAIAgCF5J4YAAAAm5V0AAGABAAAEADAU370CAgAA+DX3AADADt7Wue62AAAAFgAAn+zAAgAAWAAAAAsAACAAAJbjuQ8IAABgV+4BAAALAAAgAAAAAQAACAAA4CBHnwIRAACwIKcAAGBBFgAAEAAAgAAAAAQAACAAAAABAHAfb7kDAQAAnMBzAADAAgAACIAL8F0jAFgAAIByDwAAJ0m2239E/TLYz5XXn6stAACABQAAsAAAAAIAAA7gVJcAAAAe5B4AALAAAAACAAAQAACAAAAYmrvGQQAAAO84BQAAFgAAQAAAAAIAABAAAIAAAAAEAAAgAAAAAQAACAAAQAAAAA/57l0YAgAAFuRdAACwIAsAAAgAAEAAAAACAAAQAACAAICf++6cKgACAADYiecAAIAFAAAQAAvynTQAAgAAuCT3AACABQAAEAAAgAAAAAQAACAAAAABAAAIAABAAAAAAgAAEABwMd4xAQgAAOB03gXA3Z9gq6q628UAsAAAABYAAMACAAAIAABAAAAAAgAAEAAAgAAA4CCeVCkAAIBFeA4AAFgAAAABAAAIAABAAAAAAgAAEAAAwKfOfv6CAACABXkOAAAsyAIAAAIAABAAAIAAAAAEAAAgAAAAAQAACAAAQAAAAAIAABAAAIAAAAAEAAAgAAAAAQAACAAAQAAAAAIAAAQAACAAAAABAAAIgO8kqSSuMMDi/H9gAQAABtFVJcsAwAIAAAgAAEAAAAACAAAQAACAAACAwSRbJZsA8KsAAOvxHAAAsAAAAAIAABAAAIAAAAAEAAAgAAAAAQAACAAAQAAAAALgnSSVeFghAFgAAICHeBcAAFgAAAABAAAIAABAAAAMyekhEAAAwAecAgAACwAAIAAAAAEAAAgAAEAAAAACAAAQAACAAAAABAAAIAAA4CDeFSEAAGBZ3gUAABYAAEAAAAAfmv1eAgEAAAtyDwAAD38SrqrqbhfDAgAAWAAAfJIECwAAYAEAACwAAIAAAAAEAAAgAGBK3kYGCAAA4OmcAgDgEJ7rYAEAACwAAIAFAAAQAACAAAAABAAAIAAAAAEAAAgAAEAAAAACAAAEAAAgAAAAAQAACAAAQAAAAAIAABAAAIAAAAAEAAAgAAAAAQAAe0tSSQSAXwUAWE9XlQwCAAsAACAAAAABAAAIAABAAAAAAgBgQM6BgwAAgCV5DgAAWAAAAAEAP+S7VQABAAAMyj0AAGABAAAEAAAgAAAAAQAACAAAQAAAAAIAABAAAIAAAAAEAADD8a4PAQAATM67AADAAgAACAAAQAAAAAIAABAAAIAAgPr/3LBzxAACAAA4iecAAIAFAAAQAACAAAAAFgsAd28DgAUAAJiYUwAAYAEAAAQAACAAAAABAAAIAABAAAAAAgAAEAAAgAAAAAQAACAAAAABwEC8JRJAAAAAk/A2QACwAAAAAgAAEAAAgAAAOITTJSAAAIADOAUAABYAAEAAAAACAAAQAACAAAAABAAAIAAAAAHAYpKtks2FABAAAMBZPAkQACwAAIAAAAAEAAAgAAAAAQAACAAA+IUklTigJgAAgN15DgAAWAAAAAEAAAgAAEAAAJ9wFzMgAACA4TgFABNKtts/4H5xMU65/nm9/u1iYAEAACwAAIAFAAAQAACAAAAABAAATGuW54AIAABYkFMAwJCfoKqcswcLAABgAQAALAAAgAAAAAQAACAAzuY98QAIAADgFE4BAIAFAAAQAACAAAAABADApTilgwAAAC7NKQAAsAAAAAKA4fiOEgABAAD8insAAMACAAAIAABAAAAAAgAAEAAAgAAAYEieJ4IAAIBFeQ4AAFgAAAABAAAIAABAAAAAAgAAEAAAgAAAAAQAAIPxhEABAABcnCcBAoAFAAAQAAPx3RSAv6dYAACAB7gHAAAsAACAAAAABAAAIAAAAAEAAAgAAEAAAAACAAAQAACAAAAABAAAIAAAAAEAAAgAAEAAAAACAAAQAAAgALiwJJXEhQBAAADAqrqqfCwEAAsAACAAAAABAAAIAABAAAAAAgAAEAAAgAAAAAQAACAAAAABAAAIAABAAAAAAgAAEAAAgAAAAAHgEgCAAAAABAAAIAAWlmyVbC4EAAIAAJhTV1VcBgCwAAAAAgAAEAAAgAAAAAQAACAAAAABAAAIAABAAAAAAgAAEAAAwHUCIEklXkcAABYAAOBQ3gYIABYAAEAAAAACAAAQAACAAAAABAAAIAAAAAEAAAgAAOCZ/gLprrOgWAKxvAAAAABJRU5ErkJggg=="

local skyDaySideUrl = loadDOSEmbedded("dos_sky_day_side.png", SKY_DAY_SIDE_B64)
local skyDayTopUrl = loadDOSEmbedded("dos_sky_day_top.png", SKY_DAY_TOP_B64)
local skyDayBotUrl = loadDOSEmbedded("dos_sky_day_bot.png", SKY_DAY_BOT_B64)
local skyNightUrl = loadDOSEmbedded("dos_sky_night.png", SKY_NIGHT_B64)

local lightingUpdating = false -- (declared here, before updateRetroSkyboxAndAmbient uses it: it was a global there)
local retroPosterizeCC = nil
local retroSky = nil
local savedSkies = {}
local savedLightingProps = {}
local function crc32Bytes(str)
	local crc = 0xFFFFFFFF
	for i = 1, #str do
		crc = bit32.bxor(crc, string.byte(str, i))
		for _ = 1, 8 do
			if bit32.band(crc, 1) ~= 0 then
				crc = bit32.bxor(bit32.rshift(crc, 1), 0xEDB88320)
			else
				crc = bit32.rshift(crc, 1)
			end
		end
	end
	crc = bit32.bxor(crc, 0xFFFFFFFF)
	return string.char(
		bit32.band(bit32.rshift(crc, 24), 0xFF),
		bit32.band(bit32.rshift(crc, 16), 0xFF),
		bit32.band(bit32.rshift(crc, 8), 0xFF),
		bit32.band(crc, 0xFF)
	)
end

local function loadRecoloredSkyPNG(fileName, b64, skyCol)
	local raw = decodeBase64(b64)
	local pltePos = string.find(raw, "PLTE", 1, true)
	if not pltePos or pltePos < 5 then
		return loadDOSEmbedded(fileName, b64)
	end
	local lenB = string.sub(raw, pltePos - 4, pltePos - 1)
	local b1, b2, b3, b4 = string.byte(lenB, 1, 4)
	local chunkLen = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
	local dataStart = pltePos + 4
	local dataEnd = dataStart + chunkLen - 1
	if chunkLen < 12 or dataEnd + 4 > #raw then
		return loadDOSEmbedded(fileName, b64)
	end
	-- Infinite RGB sky colors with a slight retro polarization (posterized step + contrast) effect
	local function polarize(v)
		local q = math.floor(v / 24 + 0.5) * 24
		return math.clamp(q, 0, 255)
	end
	local r = polarize(math.floor(skyCol.R * 255 + 0.5))
	local g = polarize(math.floor(skyCol.G * 255 + 0.5))
	local b = polarize(math.floor(skyCol.B * 255 + 0.5))
	local rL = polarize(math.min(255, math.floor(r * 0.72 + 64)))
	local gL = polarize(math.min(255, math.floor(g * 0.72 + 64)))
	local bL = polarize(math.min(255, math.floor(b * 0.72 + 64)))
	local rC = polarize(math.min(255, math.floor(r * 0.22 + 195)))
	local gC = polarize(math.min(255, math.floor(g * 0.22 + 195)))
	local bC = polarize(math.min(255, math.floor(b * 0.22 + 195)))
	local newEntries = string.char(r, g, b, rL, gL, bL, rC, gC, bC, 255, 255, 255)
	local restData = string.sub(raw, dataStart + 12, dataEnd)
	local chunkBody = "PLTE" .. newEntries .. restData
	local newRaw = string.sub(raw, 1, pltePos - 1) .. chunkBody .. crc32Bytes(chunkBody) .. string.sub(raw, dataEnd + 5)
	local customFn = (type(getcustomasset) == "function" and getcustomasset) or (type(getsynasset) == "function" and getsynasset)
	if not customFn or type(writefile) ~= "function" then return nil end
	if not pcall(writefile, fileName, newRaw) then return nil end
	local okU, url = pcall(customFn, fileName)
	return (okU and type(url) == "string" and url ~= "") and url or nil
end

local detectedGameSkyColor = nil
local function detectGameSkyColor()
	-- 1. Check Atmosphere Color / Decay first
	for _, ch in ipairs(Lighting:GetChildren()) do
		if ch:IsA("Atmosphere") then
			local c = ch.Color
			local _, s = c:ToHSV()
			if s > 0.20 then return c end
			local d = ch.Decay
			local _, ds = d:ToHSV()
			if ds > 0.20 then return d end
		end
	end
	-- 2. Check FogColor if fog is active & colored
	local fogC = savedLightingProps.FogColor or Lighting.FogColor
	local fogEnd = savedLightingProps.FogEnd or Lighting.FogEnd
	if fogC and fogEnd and fogEnd < 50000 then
		local _, fs = fogC:ToHSV()
		if fs > 0.22 then return fogC end
	end
	-- 3. Check ColorShift_Top / OutdoorAmbient if strongly tinted
	local csTop = savedLightingProps.ColorShift_Top or Lighting.ColorShift_Top
	if csTop then
		local _, cs, cv = csTop:ToHSV()
		if cs > 0.28 and cv > 0.15 then return csTop end
	end
	local outAmb = savedLightingProps.OutdoorAmbient or Lighting.OutdoorAmbient
	if outAmb then
		local _, osat, oval = outAmb:ToHSV()
		if osat > 0.35 and oval > 0.20 then return outAmb end
	end
	-- 4. Check original Sky name keywords
	for skyObj in pairs(savedSkies) do
		if skyObj and skyObj.Name then
			local n = skyObj.Name:lower()
			if n:find("red") or n:find("crimson") or n:find("blood") or n:find("hell") then return Color3.fromRGB(205, 35, 35)
			elseif n:find("orange") or n:find("sunset") or n:find("lava") then return Color3.fromRGB(235, 115, 35)
			elseif n:find("purple") or n:find("violet") then return Color3.fromRGB(145, 55, 205)
			elseif n:find("green") or n:find("toxic") then return Color3.fromRGB(45, 175, 65)
			elseif n:find("pink") then return Color3.fromRGB(235, 95, 175)
			elseif n:find("yellow") or n:find("gold") then return Color3.fromRGB(225, 185, 40)
			elseif n:find("dark") or n:find("void") or n:find("black") then return Color3.fromRGB(25, 25, 35)
			end
		end
	end
	return nil
end

local function isNightTime()
	local ct = Lighting.ClockTime
	return (ct >= 17.75 or ct <= 6.25)
end

local function updateRetroSkyboxAndAmbient()
	if not enabled then return end
	local night = isNightTime()
	if CONFIG.RemoveAllShadowsAndLights then
		lightingUpdating = true
		pcall(function()
			local amb = night and Color3.fromRGB(145, 155, 190) or Color3.fromRGB(220, 220, 220)
			Lighting.Ambient = amb
			Lighting.OutdoorAmbient = amb
		end)
		lightingUpdating = false
	end
	if CONFIG.EnableRetroSkybox and retroSky and retroSky.Parent then
		if night and skyNightUrl then
			retroSky.SkyboxBk = skyNightUrl
			retroSky.SkyboxDn = skyNightUrl
			retroSky.SkyboxFt = skyNightUrl
			retroSky.SkyboxLf = skyNightUrl
			retroSky.SkyboxRt = skyNightUrl
			retroSky.SkyboxUp = skyNightUrl
		elseif skyDaySideUrl and skyDayTopUrl and skyDayBotUrl then
			retroSky.SkyboxBk = skyDaySideUrl
			retroSky.SkyboxDn = skyDayBotUrl
			retroSky.SkyboxFt = skyDaySideUrl
			retroSky.SkyboxLf = skyDaySideUrl
			retroSky.SkyboxRt = skyDaySideUrl
			retroSky.SkyboxUp = skyDayTopUrl
		end
	end
end

local savedLightObjects = {}
local savedShadowParts = {}
local retroColorGrading = nil

local FLAT_LIGHTING_PROPS = {
	"GlobalShadows",
	"Brightness",
	"Ambient",
	"OutdoorAmbient",
	"ColorShift_Top",
	"ColorShift_Bottom",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"ShadowSoftness",
	"FogEnd",
	"FogStart",
	"ExposureCompensation",
}

local function suppressLightOrShadow(inst)
	if not CONFIG.RemoveAllShadowsAndLights then return end
	if inst == retroColorGrading or inst == retroPosterizeCC or inst == retroSky then return end
	if inst:IsA("Light") or inst:IsA("PostEffect") or inst:IsA("Clouds") then
		if savedLightObjects[inst] == nil then
			pcall(function() savedLightObjects[inst] = { Enabled = inst.Enabled } end)
		end
		pcall(function() inst.Enabled = false end)
	elseif inst:IsA("Atmosphere") then
		if savedLightObjects[inst] == nil then
			pcall(function() savedLightObjects[inst] = { Density = inst.Density } end)
		end
		pcall(function() inst.Density = 0 end)
	elseif inst:IsA("BasePart") then
		if savedShadowParts[inst] == nil then
			savedShadowParts[inst] = { CastShadow = inst.CastShadow, Reflectance = inst.Reflectance }
		end
		inst.CastShadow = false
		inst.Reflectance = 0
	end
end

local function applyFlatLightingProps()
	if lightingUpdating then return end
	lightingUpdating = true
	pcall(function()
		Lighting.GlobalShadows = false
		Lighting.ShadowSoftness = 0
		Lighting.Brightness = 0 -- Eliminates SmoothPlastic directional shine
		Lighting.Ambient = Color3.fromRGB(220, 220, 220)
		Lighting.OutdoorAmbient = Color3.fromRGB(220, 220, 220)
		Lighting.ColorShift_Top = Color3.new(0, 0, 0)
		Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0
		Lighting.FogStart = 200000
		Lighting.FogEnd = 200000
		Lighting.ExposureCompensation = 0
	end)
	lightingUpdating = false
end

local function enableFlatLightingAndNoShadows()
	if not CONFIG.RemoveAllShadowsAndLights then return end
	for _, prop in ipairs(FLAT_LIGHTING_PROPS) do
		if savedLightingProps[prop] == nil then
			pcall(function() savedLightingProps[prop] = Lighting[prop] end)
		end
	end
	applyFlatLightingProps()

	if not retroColorGrading or not retroColorGrading.Parent then
		pcall(function()
			local cg = Instance.new("ColorGradingEffect")
			cg.Name = "ESpritesRetroGrading"
			cg.TonemapperPreset = Enum.TonemapperPreset.Retro
			cg.Enabled = true
			cg.Parent = Lighting
			retroColorGrading = cg
		end)
	end

	if CONFIG.EnablePosterization and (not retroPosterizeCC or not retroPosterizeCC.Parent) then
		pcall(function()
			local cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "ESpritesRetroPosterize"
			cc.Contrast = 0.28
			cc.Saturation = 0.22
			cc.Enabled = true
			cc.Parent = Lighting
			retroPosterizeCC = cc
		end)
	end

	if CONFIG.EnableRetroSkybox and (not retroSky or not retroSky.Parent) then
		for _, ch in ipairs(Lighting:GetChildren()) do
			if ch:IsA("Sky") and ch ~= retroSky then
				savedSkies[ch] = ch.Parent
				ch.Parent = nil
			end
		end
		pcall(function()
			local sky = Instance.new("Sky")
			sky.Name = "ESpritesRetroSky"
			sky.CelestialBodiesShown = false
			sky.StarCount = 0
			sky.Parent = Lighting
			retroSky = sky
		end)
	end
	detectedGameSkyColor = detectGameSkyColor()
	if detectedGameSkyColor then
		skyDaySideUrl = loadRecoloredSkyPNG("dos_sky_day_side_auto.png", SKY_DAY_SIDE_B64, detectedGameSkyColor) or skyDaySideUrl
		skyDayTopUrl  = loadRecoloredSkyPNG("dos_sky_day_top_auto.png", SKY_DAY_TOP_B64, detectedGameSkyColor) or skyDayTopUrl
		skyDayBotUrl  = loadRecoloredSkyPNG("dos_sky_day_bot_auto.png", SKY_DAY_BOT_B64, detectedGameSkyColor) or skyDayBotUrl
	end
	updateRetroSkyboxAndAmbient()

	for _, desc in ipairs(Lighting:GetDescendants()) do
		suppressLightOrShadow(desc)
	end
	for _, desc in ipairs(Workspace:GetDescendants()) do
		suppressLightOrShadow(desc)
	end
end

local function disableFlatLightingAndNoShadows()
	lightingUpdating = true
	for prop, val in pairs(savedLightingProps) do
		pcall(function() Lighting[prop] = val end)
	end
	lightingUpdating = false
	if retroColorGrading and retroColorGrading.Parent then
		retroColorGrading:Destroy()
		retroColorGrading = nil
	end
	if retroPosterizeCC and retroPosterizeCC.Parent then
		retroPosterizeCC:Destroy()
		retroPosterizeCC = nil
	end
	if retroSky and retroSky.Parent then
		retroSky:Destroy()
		retroSky = nil
	end
	for skyObj, origParent in pairs(savedSkies) do
		if skyObj and origParent and origParent.Parent then
			pcall(function() skyObj.Parent = origParent end)
		end
	end
	table.clear(savedSkies)
	for inst, state in pairs(savedLightObjects) do
		if inst and inst.Parent then
			pcall(function()
				if state.Enabled ~= nil then inst.Enabled = state.Enabled end
				if state.Density ~= nil then inst.Density = state.Density end
			end)
		end
	end
	table.clear(savedLightObjects)
	for part, state in pairs(savedShadowParts) do
		if part and part.Parent then
			pcall(function()
				part.CastShadow = state.CastShadow
				part.Reflectance = state.Reflectance
			end)
		end
	end
	table.clear(savedShadowParts)
end

-- ============================================================================
-- RETRO MS-DOS HUD
-- ============================================================================
local retroHudGui = nil
local retroHudConns = {}
local hudHealthFill = nil
local hudHpText = nil
local hudChatScroll = nil
local hudSlotButtons = {}
local hudSlotTools = {}
local savedTopBarEnabled = nil
local savedExpChatEnabled = nil
local savedTopbarPlusGuis = {}
local TOPBAR_PLUS_NAMES = {
	TopbarStandard = true,
	TopbarCentered = true,
	TopbarPlus = true,
	Topbar = true,
}

local function setCoreGuiVisible(visible)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, visible)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, visible)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, visible)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, visible)
	end)
	pcall(function()
		local topBar = CoreGui:FindFirstChild("TopBarApp")
		if topBar then
			local inner = topBar:FindFirstChild("TopBarApp")
			if inner then
				if savedTopBarEnabled == nil then
					savedTopBarEnabled = inner.Enabled
				end
				inner.Enabled = visible and savedTopBarEnabled or false
			elseif topBar:IsA("ScreenGui") then
				topBar.Enabled = visible
			end
		end
	end)
	pcall(function()
		local expChat = CoreGui:FindFirstChild("ExperienceChat")
		if expChat and expChat:IsA("ScreenGui") then
			if savedExpChatEnabled == nil then
				savedExpChatEnabled = expChat.Enabled
			end
			expChat.Enabled = visible and savedExpChatEnabled or false
		end
	end)
	pcall(function()
		local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		for _, container in ipairs({ pGui, CoreGui }) do
			if container then
				for _, ch in ipairs(container:GetChildren()) do
					if ch:IsA("ScreenGui") and (TOPBAR_PLUS_NAMES[ch.Name] or ch.Name:lower():find("topbar")) then
						if savedTopbarPlusGuis[ch] == nil then
							savedTopbarPlusGuis[ch] = ch.Enabled
						end
						ch.Enabled = visible and savedTopbarPlusGuis[ch] or false
					end
				end
			end
		end
	end)
end

local function sendChatMessage(msg)
	if type(msg) ~= "string" or msg:match("^%s*$") then return end
	local sent = false
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and (channels:FindFirstChild("RBXGeneral") or channels:FindFirstChildOfClass("TextChannel"))
		if general then
			general:SendAsync(msg)
			sent = true
		end
	end)
	if not sent then
		pcall(function()
			local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
			local sayReq = chatEvents and chatEvents:FindFirstChild("SayMessageRequest")
			if sayReq then
				sayReq:FireServer(msg, "All")
			end
		end)
	end
end

local function appendHudChatLine(senderName, msgText, color3)
	if not hudChatScroll or not hudChatScroll.Parent then return end
	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.Size = UDim2.new(1, -6, 0, 14)
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.TextWrapped = true
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.Text = (senderName and (senderName .. ": ") or "") .. tostring(msgText)
	line.TextColor3 = color3 or Color3.fromRGB(0xAA, 0x00, 0x00)
	line.TextSize = 12
	pcall(function() line.Font = Enum.Font.Arcade end)
	line.Parent = hudChatScroll

	local labels = {}
	for _, c in ipairs(hudChatScroll:GetChildren()) do
		if c:IsA("TextLabel") then table.insert(labels, c) end
	end
	if #labels > 40 then labels[1]:Destroy() end
	task.defer(function()
		if hudChatScroll and hudChatScroll.Parent then
			hudChatScroll.CanvasPosition = Vector2.new(0, math.max(0, hudChatScroll.AbsoluteCanvasSize.Y))
		end
	end)
end

local function refreshHudInventory()
	if not retroHudGui or not retroHudGui.Parent then return end
	local char = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local equipped = char and char:FindFirstChildOfClass("Tool")

	local tools = {}
	if equipped then table.insert(tools, equipped) end
	if backpack then
		for _, t in ipairs(backpack:GetChildren()) do
			if t:IsA("Tool") then table.insert(tools, t) end
		end
	end

	for i = 1, 8 do
		local btn = hudSlotButtons[i]
		local tool = tools[i]
		hudSlotTools[i] = tool
		if btn and btn.Parent then
			local icon = btn:FindFirstChild("Icon")
			local lbl = btn:FindFirstChild("Label")
			local stroke = btn:FindFirstChild("SelStroke")
			if tool then
				local texId = ""
				pcall(function() texId = tool.TextureId end)
				if type(texId) == "string" and texId ~= "" then
					icon.Image = texId
					icon.Visible = true
					lbl.Visible = false
				else
					icon.Visible = false
					lbl.Text = tool.Name
					lbl.Visible = true
				end
				if stroke then
					stroke.Color = (tool == equipped) and Color3.fromRGB(0xFF, 0xFF, 0x55) or Color3.fromRGB(0x55, 0x55, 0x55)
					stroke.Thickness = (tool == equipped) and 2 or 1.5
				end
			else
				icon.Visible = false
				lbl.Visible = false
				if stroke then
					stroke.Color = Color3.fromRGB(0x55, 0x55, 0x55)
					stroke.Thickness = 1.5
				end
			end
		end
	end
end

local function destroyRetroHUD()
	for _, c in ipairs(retroHudConns) do
		if c and c.Connected then c:Disconnect() end
	end
	table.clear(retroHudConns)
	table.clear(hudSlotButtons)
	table.clear(hudSlotTools)
	hudHealthFill = nil
	hudHpText = nil
	hudChatScroll = nil
	if retroHudGui and retroHudGui.Parent then
		retroHudGui:Destroy()
	end
	retroHudGui = nil
	setCoreGuiVisible(true)
end

local function createRetroHUD()
	destroyRetroHUD()
	if not enabled or not CONFIG.EnableRetroHUD then return end

	setCoreGuiVisible(false)

	local gui = Instance.new("ScreenGui")
	gui.Name = "ESpritesRetroHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = -1
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	retroHudGui = gui

	-- Compact fixed-proportion container at bottom-left
	local container = Instance.new("Frame")
	container.Name = "HUDRoot"
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0, 1)
	container.Position = UDim2.new(0, 0, 1, 0)
	container.Size = UDim2.fromOffset(600, 134)
	container.Parent = gui

	if UserInputService.TouchEnabled then
		local uiScale = Instance.new("UIScale")
		uiScale.Scale = 0.75
		uiScale.Parent = container
	end

	-- Left taller panel (270 x 134)
	local leftPanel = Instance.new("Frame")
	leftPanel.Name = "LeftPanel"
	leftPanel.BackgroundColor3 = Color3.fromRGB(0xA8, 0xA8, 0xA8)
	leftPanel.BorderColor3 = Color3.fromRGB(0x55, 0x55, 0x55)
	leftPanel.BorderSizePixel = 2
	leftPanel.Active = false
	leftPanel.Position = UDim2.fromOffset(0, 0)
	leftPanel.Size = UDim2.fromOffset(270, 134)
	leftPanel.Parent = container

	local lpTop = Instance.new("Frame")
	lpTop.BackgroundColor3 = Color3.new(1, 1, 1)
	lpTop.BorderSizePixel = 0
	lpTop.Size = UDim2.new(1, 0, 0, 2)
	lpTop.Parent = leftPanel
	local lpLeft = Instance.new("Frame")
	lpLeft.BackgroundColor3 = Color3.new(1, 1, 1)
	lpLeft.BorderSizePixel = 0
	lpLeft.Size = UDim2.new(0, 2, 1, 0)
	lpLeft.Parent = leftPanel

	local hpBg = Instance.new("Frame")
	hpBg.Name = "HealthBG"
	hpBg.BackgroundColor3 = Color3.fromRGB(0xCC, 0x00, 0x00)
	hpBg.BorderColor3 = Color3.fromRGB(0x00, 0x66, 0x00)
	hpBg.BorderSizePixel = 2
	hpBg.Position = UDim2.fromOffset(8, 7)
	hpBg.Size = UDim2.fromOffset(145, 16)
	hpBg.Parent = leftPanel

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HealthFill"
	hpFill.BackgroundColor3 = Color3.fromRGB(0x00, 0xFF, 0x00)
	hpFill.BorderSizePixel = 0
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.Parent = hpBg
	hudHealthFill = hpFill

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.BackgroundTransparency = 1
	hpText.Position = UDim2.fromOffset(158, 5)
	hpText.Size = UDim2.fromOffset(54, 20)
	hpText.Text = "HP 100"
	hpText.TextColor3 = Color3.fromRGB(0xFF, 0xFF, 0x55)
	hpText.TextStrokeColor3 = Color3.new(0, 0, 0)
	hpText.TextStrokeTransparency = 0
	hpText.TextXAlignment = Enum.TextXAlignment.Left
	hpText.TextScaled = true
	pcall(function() hpText.Font = Enum.Font.Arcade end)
	hpText.Parent = leftPanel
	hudHpText = hpText

	local leaveBtn = Instance.new("TextButton")
	leaveBtn.Name = "LeaveButton"
	leaveBtn.BackgroundColor3 = Color3.fromRGB(0xFF, 0x33, 0x33)
	leaveBtn.BorderColor3 = Color3.fromRGB(0xAA, 0x00, 0x00)
	leaveBtn.BorderSizePixel = 2
	local catBtn = Instance.new("TextButton")
	catBtn.Name = "CatalogButton"
	catBtn.BackgroundColor3 = Color3.fromRGB(0x33, 0x88, 0xFF)
	catBtn.BorderColor3 = Color3.fromRGB(0x00, 0x44, 0xAA)
	catBtn.BorderSizePixel = 2
	catBtn.Position = UDim2.fromOffset(214, 4)
	catBtn.Size = UDim2.fromOffset(24, 22)
	catBtn.Text = "C"
	catBtn.TextColor3 = Color3.new(1, 1, 1)
	catBtn.TextSize = 16
	pcall(function() catBtn.Font = Enum.Font.Arcade end)
	catBtn.Parent = leftPanel

	leaveBtn.Position = UDim2.fromOffset(242, 4)
	leaveBtn.Size = UDim2.fromOffset(24, 22)
	leaveBtn.Text = "L"
	leaveBtn.TextColor3 = Color3.fromRGB(0x66, 0x00, 0x00)
	leaveBtn.TextSize = 16
	pcall(function() leaveBtn.Font = Enum.Font.Arcade end)
	leaveBtn.Parent = leftPanel

	table.insert(retroHudConns, leaveBtn.MouseButton1Click:Connect(function()
		pcall(function() game:Shutdown() end)
		pcall(function() LocalPlayer:Kick("Left game.") end)
	end))

	local chatBox = Instance.new("Frame")
	chatBox.Name = "ChatBox"
	chatBox.BackgroundColor3 = Color3.new(1, 1, 1)
	chatBox.BorderColor3 = Color3.fromRGB(0x55, 0x55, 0x55)
	chatBox.BorderSizePixel = 2
	chatBox.Position = UDim2.fromOffset(8, 30)
	chatBox.Size = UDim2.fromOffset(252, 96)
	chatBox.Parent = leftPanel



	local chatScroll = Instance.new("ScrollingFrame")
	chatScroll.Name = "ChatLogs"
	chatScroll.BackgroundTransparency = 1
	chatScroll.BorderSizePixel = 0
	chatScroll.Position = UDim2.fromOffset(4, 3)
	chatScroll.Size = UDim2.fromOffset(244, 68)
	chatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	chatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	chatScroll.ScrollBarThickness = 3
	chatScroll.ZIndex = 2
	chatScroll.Parent = chatBox
	hudChatScroll = chatScroll

	local chatLayout = Instance.new("UIListLayout")
	chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chatLayout.Padding = UDim.new(0, 2)
	chatLayout.Parent = chatScroll

	local chatInput = Instance.new("TextBox")
	chatInput.Name = "ChatInput"
	chatInput.BackgroundColor3 = Color3.fromRGB(0xEE, 0xEE, 0xEE)
	chatInput.BorderColor3 = Color3.fromRGB(0xAA, 0xAA, 0xAA)
	chatInput.BorderSizePixel = 1
	chatInput.Position = UDim2.fromOffset(4, 73)
	chatInput.Size = UDim2.fromOffset(212, 19)
	chatInput.Text = ""
	chatInput.PlaceholderText = "Type here to chat..."
	chatInput.PlaceholderColor3 = Color3.fromRGB(0x77, 0x77, 0x77)
	chatInput.TextColor3 = Color3.new(0, 0, 0)
	chatInput.TextXAlignment = Enum.TextXAlignment.Left
	chatInput.ClearTextOnFocus = false
	chatInput.TextSize = 12
	chatInput.ZIndex = 2
	pcall(function() chatInput.Font = Enum.Font.Arcade end)
	chatInput.Parent = chatBox

	local sendBtn = Instance.new("TextButton")
	sendBtn.Name = "SendBtn"
	sendBtn.BackgroundColor3 = Color3.fromRGB(0xA8, 0xA8, 0xA8)
	sendBtn.BorderColor3 = Color3.fromRGB(0x55, 0x55, 0x55)
	sendBtn.BorderSizePixel = 1
	sendBtn.Position = UDim2.fromOffset(218, 73)
	sendBtn.Size = UDim2.fromOffset(30, 19)
	sendBtn.Text = ">"
	sendBtn.TextColor3 = Color3.new(0, 0, 0)
	sendBtn.TextSize = 14
	sendBtn.ZIndex = 2
	pcall(function() sendBtn.Font = Enum.Font.Arcade end)
	sendBtn.Parent = chatBox

	local function submitHudChat()
		local msg = chatInput.Text
		if msg ~= "" and not msg:match("^%s*$") then
			chatInput.Text = ""
			sendChatMessage(msg)
			task.defer(function()
				pushPixelChatBubble(LocalPlayer, msg)
			end)
		end
	end

	table.insert(retroHudConns, sendBtn.MouseButton1Click:Connect(submitHudChat))
	table.insert(retroHudConns, chatInput.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submitHudChat()
		end
	end))

	-- Right shorter inventory wing (328 x 48, 8 square 36x36 slots)
	local rightPanel = Instance.new("Frame")
	rightPanel.Name = "InventoryPanel"
	rightPanel.BackgroundColor3 = Color3.fromRGB(0xA8, 0xA8, 0xA8)
	rightPanel.BorderColor3 = Color3.fromRGB(0x55, 0x55, 0x55)
	rightPanel.BorderSizePixel = 2
	rightPanel.Active = false
	rightPanel.Position = UDim2.fromOffset(272, 86)
	rightPanel.Size = UDim2.fromOffset(328, 48)
	rightPanel.Parent = container

	local invGrid = Instance.new("Frame")
	invGrid.BackgroundTransparency = 1
	invGrid.Position = UDim2.fromOffset(6, 6)
	invGrid.Size = UDim2.fromOffset(316, 36)
	invGrid.Parent = rightPanel

	local gridLayout = Instance.new("UIListLayout")
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	gridLayout.Padding = UDim.new(0, 4)
	gridLayout.Parent = invGrid

	for i = 1, 8 do
		local slot = Instance.new("TextButton")
		slot.Name = "Slot" .. i
		slot.BackgroundColor3 = Color3.fromRGB(0xA8, 0xA8, 0xA8)
		slot.BorderSizePixel = 0
		slot.Size = UDim2.fromOffset(36, 36)
		slot.Text = ""
		slot.AutoButtonColor = false
		slot.Parent = invGrid

		local stroke = Instance.new("UIStroke")
		stroke.Name = "SelStroke"
		stroke.Color = Color3.fromRGB(0x55, 0x55, 0x55)
		stroke.Thickness = 1.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = slot

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Position = UDim2.fromScale(0.1, 0.1)
		icon.Size = UDim2.fromScale(0.8, 0.8)
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Visible = false
		pcall(function() icon.ResampleMode = Enum.ResamplerMode.Pixelated end)
		icon.Parent = slot

		local lbl = Instance.new("TextLabel")
		lbl.Name = "Label"
		lbl.BackgroundTransparency = 1
		lbl.Position = UDim2.fromScale(0.05, 0.05)
		lbl.Size = UDim2.fromScale(0.9, 0.9)
		lbl.TextColor3 = Color3.new(0, 0, 0)
		lbl.TextWrapped = true
		lbl.TextScaled = true
		lbl.Visible = false
		pcall(function() lbl.Font = Enum.Font.Arcade end)
		lbl.Parent = slot

		hudSlotButtons[i] = slot

		table.insert(retroHudConns, slot.MouseButton1Click:Connect(function()
			local t = hudSlotTools[i]
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum then return end
			if t and t.Parent == char then
				hum:UnequipTools()
			elseif t then
				hum:EquipTool(t)
			end
			task.defer(refreshHudInventory)
		end))
	end

	local numKeys = {
		Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
		Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight,
	}
	table.insert(retroHudConns, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		for idx, kc in ipairs(numKeys) do
			if input.KeyCode == kc then
				local t = hudSlotTools[idx]
				local char = LocalPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum then
					if t and t.Parent == char then
						hum:UnequipTools()
					elseif t then
						hum:EquipTool(t)
					end
					task.defer(refreshHudInventory)
				end
				break
			end
		end
	end))

	local function hookInvContainer(cont)
		if not cont then return end
		table.insert(retroHudConns, cont.ChildAdded:Connect(function() task.defer(refreshHudInventory) end))
		table.insert(retroHudConns, cont.ChildRemoved:Connect(function() task.defer(refreshHudInventory) end))
	end
	hookInvContainer(LocalPlayer:FindFirstChildOfClass("Backpack"))
	hookInvContainer(LocalPlayer.Character)
	table.insert(retroHudConns, LocalPlayer.CharacterAdded:Connect(function(c)
		task.wait(0.2)
		hookInvContainer(c)
		hookInvContainer(LocalPlayer:FindFirstChildOfClass("Backpack"))
		refreshHudInventory()
	end))


	-- Classic MS-DOS Catalog Window (toggled by C button)
	local catWin = Instance.new("Frame")
	catWin.Name = "CatalogWindow"
	catWin.BackgroundColor3 = Color3.fromRGB(0xA8, 0xA8, 0xA8)
	catWin.BorderColor3 = Color3.fromRGB(0x55, 0x55, 0x55)
	catWin.BorderSizePixel = 3
	catWin.AnchorPoint = Vector2.new(0.5, 0.5)
	catWin.Position = UDim2.fromScale(0.5, 0.45)
	catWin.Size = UDim2.fromOffset(356, 244)
	catWin.Visible = false
	catWin.ZIndex = 20
	catWin.Parent = gui

	local catClose = Instance.new("TextButton")
	catClose.BackgroundColor3 = Color3.fromRGB(0xFF, 0x33, 0x33)
	catClose.BorderSizePixel = 0
	catClose.Position = UDim2.new(1, -28, 0, 6)
	catClose.Size = UDim2.fromOffset(22, 22)
	catClose.Text = "X"
	catClose.TextColor3 = Color3.new(1, 1, 1)
	catClose.TextSize = 13
	catClose.ZIndex = 22
	pcall(function() catClose.Font = Enum.Font.Arcade end)
	catClose.Parent = catWin

	table.insert(retroHudConns, catBtn.MouseButton1Click:Connect(function()
		catWin.Visible = not catWin.Visible
	end))
	table.insert(retroHudConns, catClose.MouseButton1Click:Connect(function()
		catWin.Visible = false
	end))

	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(6, 6)
	tabBar.Size = UDim2.new(1, -38, 0, 24)
	tabBar.ZIndex = 21
	tabBar.Parent = catWin

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.Parent = tabBar

	local catScroll = Instance.new("ScrollingFrame")
	catScroll.BackgroundColor3 = Color3.fromRGB(0xDD, 0xDD, 0xDD)
	catScroll.BorderColor3 = Color3.fromRGB(0x55, 0x55, 0x55)
	catScroll.BorderSizePixel = 2
	catScroll.Position = UDim2.fromOffset(6, 34)
	catScroll.Size = UDim2.new(1, -12, 1, -40)
	catScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	catScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	catScroll.ScrollBarThickness = 5
	catScroll.ZIndex = 21
	catScroll.Parent = catWin

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(78, 34)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.Parent = catScroll

	local function rebuildLocalSprite()
		if LocalPlayer.Character and enabled then
			task.spawn(buildRigForPlayer, LocalPlayer, LocalPlayer.Character)
		end
	end

	local function clearCatalogItems()
		for _, ch in ipairs(catScroll:GetChildren()) do
			if ch:IsA("TextButton") then ch:Destroy() end
		end
	end

	local function addCatBtn(label, bgCol, onClick)
		local b = Instance.new("TextButton")
		b.BackgroundColor3 = bgCol or Color3.fromRGB(0xA8, 0xA8, 0xA8)
		b.BorderColor3 = Color3.fromRGB(0x55, 0x55, 0x55)
		b.BorderSizePixel = 2
		b.Text = label
		b.TextColor3 = Color3.new(0, 0, 0)
		b.TextWrapped = true
		b.TextScaled = true
		b.ZIndex = 22
		pcall(function() b.Font = Enum.Font.Arcade end)
		b.Parent = catScroll
		table.insert(retroHudConns, b.MouseButton1Click:Connect(onClick))
	end

	local function showTab(tabName)
		clearCatalogItems()
		if tabName == "Hats" then
			addCatBtn("None", nil, function() localCustom.hat = "None"; rebuildLocalSprite() end)
			addCatBtn(localCustom.shades and "Shades:ON" or "Shades", nil, function()
				localCustom.shades = not localCustom.shades
				rebuildLocalSprite()
				showTab("Hats")
			end)
			for _, h in ipairs(HAT_STYLES) do
				addCatBtn(h, nil, function() localCustom.hat = h; rebuildLocalSprite() end)
			end
		elseif tabName == "Faces" then
			for _, fName in ipairs(FACE_STYLES) do
				addCatBtn(fName, nil, function() localCustom.face = fName; rebuildLocalSprite() end)
			end
		elseif tabName == "Shirts" then
			addCatBtn("None", nil, function() localCustom.shirt = "None"; rebuildLocalSprite() end)
			for _, s in ipairs(SHIRT_STYLES) do
				addCatBtn(s, nil, function() localCustom.shirt = s; rebuildLocalSprite() end)
			end
		elseif tabName == "Pants" then
			addCatBtn("None", nil, function() localCustom.pants = "None"; rebuildLocalSprite() end)
			for _, p in ipairs(PANTS_STYLES) do
				addCatBtn(p, nil, function() localCustom.pants = p; rebuildLocalSprite() end)
			end
		elseif tabName == "Colors" then
			addCatBtn("Reset", Color3.fromRGB(255, 255, 160), function()
				localCustom.skinColor = nil
				localCustom.torsoColor = nil
				localCustom.legsColor = nil
				rebuildLocalSprite()
			end)
			for i, col in ipairs(SKIN_PALETTE) do
				addCatBtn("Skin " .. i, col, function()
					localCustom.skinColor = col
					rebuildLocalSprite()
				end)
			end
			for i, opt in ipairs(OUTFIT_PALETTE) do
				addCatBtn("Top " .. i, opt.color, function()
					localCustom.torsoColor = opt
					rebuildLocalSprite()
				end)
			end
			for i, opt in ipairs(OUTFIT_PALETTE) do
				addCatBtn("Leg " .. i, opt.color, function()
					localCustom.legsColor = opt
					rebuildLocalSprite()
				end)
			end
		end
	end

	for _, tName in ipairs({ "Hats", "Faces", "Shirts", "Pants", "Colors" }) do
		local tb = Instance.new("TextButton")
		tb.BackgroundColor3 = Color3.fromRGB(0x88, 0x88, 0x88)
		tb.BorderColor3 = Color3.fromRGB(0x44, 0x44, 0x44)
		tb.BorderSizePixel = 2
		tb.Size = UDim2.fromOffset(58, 24)
		tb.Text = tName
		tb.TextColor3 = Color3.new(1, 1, 1)
		tb.TextSize = 12
		tb.ZIndex = 22
		pcall(function() tb.Font = Enum.Font.Arcade end)
		tb.Parent = tabBar
		table.insert(retroHudConns, tb.MouseButton1Click:Connect(function()
			showTab(tName)
		end))
	end
	showTab("Hats")

	refreshHudInventory()
end


local CHAT_BOX_B64 = "iVBORw0KGgoAAAANSUhEUgAAABsAAAANCAYAAABYWxXTAAAAQElEQVR42mNctWrVfwY6ASYGOgIWGCM0NJRmlqxevZr+Phu1bNSyEWoZC3rGwwXwZXpCekn2GS4DibWIgYGBAQBowQ8eDaV0DgAAAABJRU5ErkJggg=="
local CHAT_TAIL_B64 = "iVBORw0KGgoAAAANSUhEUgAAAAsAAAAHCAYAAADebrddAAAAMElEQVR42mNYtWrVf2LAqlWr/jMxkAoImb5q1ar/RGnAUIhLA06F6BoIKkTWgE0cAE6XhH59NJ/QAAAAAElFTkSuQmCC"
local chatBoxUrl = loadDOSEmbedded("dos_chat_box.png", CHAT_BOX_B64)
local chatTailUrl = loadDOSEmbedded("dos_chat_tail.png", CHAT_TAIL_B64)
local savedBubbleChatEnabled = nil
local recentChats = {} -- Player -> { lastText = ..., lastTime = ... }
local playerChatStacks = {} -- Player -> { gui = BillboardGui, list = { ... } }

local function setRobloxDefaultBubbles(state)
	pcall(function()
		local cfg = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
		if cfg then
			if savedBubbleChatEnabled == nil then
				savedBubbleChatEnabled = cfg.Enabled
			end
			cfg.Enabled = state
		end
	end)
end

if CONFIG.EnablePixelChatBubbles then
	setRobloxDefaultBubbles(false)
end

local function destroyPlayerChatStack(player)
	local st = playerChatStacks[player]
	if st and st.gui and st.gui.Parent then
		st.gui:Destroy()
	end
	playerChatStacks[player] = nil
end

pushPixelChatBubble = function(player, msgText)
	if enabled and CONFIG.EnableRetroHUD and type(msgText) == "string" and msgText ~= "" then
		local now = os.clock()
		local prev = recentChats[player]
		if not (prev and prev.text == msgText and (now - prev.t) < 2.0) then
			local col = (player == LocalPlayer) and Color3.fromRGB(0x00, 0xAA, 0x00)
				or Color3.fromRGB(0xAA, 0x00, 0x00)
			appendHudChatLine(player.DisplayName or player.Name, msgText, col)
		end
	end
	if not enabled or not CONFIG.EnablePixelChatBubbles then return end
	if type(msgText) ~= "string" or msgText == "" then return end
	local rig = playerRigs[player]
	if not rig or not rig.hrp or not rig.hrp.Parent then return end

	-- Dedupe if both TextChatService and Player.Chatted fire for the same message
	local now = os.clock()
	local prev = recentChats[player]
	if prev and prev.text == msgText and (now - prev.t) < 2.0 then
		return
	end
	recentChats[player] = { text = msgText, t = now }

	local st = playerChatStacks[player]
	if not st or not st.gui or not st.gui.Parent then
		local cbb = Instance.new("BillboardGui")
		cbb.Name = "ESpritesChat_" .. player.Name
		cbb.Adornee = rig.hrp
		cbb.Size = UDim2.fromScale(4.6, 2.8)
		cbb.StudsOffset = Vector3.new(0, 5.2, 0)
		cbb.MaxDistance = 120
		cbb.AlwaysOnTop = false
		cbb.LightInfluence = 0
		cbb.ResetOnSpawn = false
		cbb.Parent = getBillboardParent()

		local holder = Instance.new("Frame")
		holder.Name = "Holder"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.Parent = cbb

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		layout.Padding = UDim.new(0.03, 0)
		layout.Parent = holder

		st = { gui = cbb, holder = holder, bubbles = {} }
		playerChatStacks[player] = st
	end

	-- Trim oldest bubble if at max
	while #st.bubbles >= CONFIG.MaxChatBubbles do
		local oldest = table.remove(st.bubbles, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end

	-- Hide tail on previous bottom bubble
	for _, b in ipairs(st.bubbles) do
		local t = b:FindFirstChild("Tail")
		if t then t.Visible = false end
	end

	local wrap = Instance.new("Frame")
	wrap.Name = "Bubble"
	wrap.BackgroundTransparency = 1
	local charCount = #msgText
	local wScale = math.clamp(0.38 + charCount * 0.022, 0.42, 0.98)
	local linesCount = math.max(1, math.ceil(charCount / 22))
	local hScale = math.clamp(0.22 + (linesCount - 1) * 0.11, 0.24, 0.50)
	wrap.Size = UDim2.fromScale(wScale, hScale)
	wrap.Parent = st.holder

	local box = Instance.new("ImageLabel")
	box.Name = "Box"
	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0
	box.Size = UDim2.fromScale(1, 0.78)
	box.Position = UDim2.fromScale(0, 0)
	box.ZIndex = 2
	if chatBoxUrl then
		box.Image = chatBoxUrl
		box.ScaleType = Enum.ScaleType.Stretch
		pcall(function() box.ResampleMode = Enum.ResamplerMode.Pixelated end)
	else
		box.BackgroundTransparency = 0
		box.BackgroundColor3 = Color3.new(1, 1, 1)
		box.BorderSizePixel = 2
		box.BorderColor3 = Color3.fromRGB(165, 165, 165)
	end
	box.Parent = wrap

	local txt = Instance.new("TextLabel")
	txt.Name = "Msg"
	txt.BackgroundTransparency = 1
	txt.Position = UDim2.fromScale(0.08, 0.14)
	txt.Size = UDim2.fromScale(0.84, 0.72)
	txt.Text = msgText
	txt.TextColor3 = Color3.new(0, 0, 0)
	txt.TextWrapped = true
	txt.TextScaled = true
	txt.ZIndex = 4
	pcall(function() txt.Font = Enum.Font.Arcade end)
	txt.Parent = box

	local tail = Instance.new("ImageLabel")
	tail.Name = "Tail"
	tail.BackgroundTransparency = 1
	tail.BorderSizePixel = 0
	tail.AnchorPoint = Vector2.new(0.5, 0)
	tail.SizeConstraint = Enum.SizeConstraint.RelativeYY
	tail.Position = UDim2.fromScale(0.5, 0.70)
	tail.Size = UDim2.fromScale(0.45, 0.28)
	tail.ZIndex = 3
	if chatTailUrl then
		tail.Image = chatTailUrl
		tail.ScaleType = Enum.ScaleType.Stretch
		pcall(function() tail.ResampleMode = Enum.ResamplerMode.Pixelated end)
	end
	tail.Parent = wrap

	table.insert(st.bubbles, wrap)

	task.delay(CONFIG.ChatBubbleDuration, function()
		if wrap and wrap.Parent then
			wrap:Destroy()
		end
		if st and st.bubbles then
			for i, b in ipairs(st.bubbles) do
				if b == wrap then
					table.remove(st.bubbles, i)
					break
				end
			end
			local last = st.bubbles[#st.bubbles]
			if last then
				local t = last:FindFirstChild("Tail")
				if t then t.Visible = true end
			elseif st.gui and st.gui.Parent then
				st.gui:Destroy()
				playerChatStacks[player] = nil
			end
		end
	end)
end

local function hookPlayer(player)
	if player ~= LocalPlayer and not CONFIG.ApplyToAllPlayers then
		return
	end
	if playerConns[player] then
		return
	end
	playerConns[player] = {}
	table.insert(playerConns[player], player.Chatted:Connect(function(msg)
		pushPixelChatBubble(player, msg)
	end))
	table.insert(playerConns[player], player.CharacterAdded:Connect(function(char)
		task.wait(0.15)
		if enabled then
			buildRigForPlayer(player, char)
		end
	end))
	if player.Character and enabled then
		task.spawn(buildRigForPlayer, player, player.Character)
	end
end

local function unhookPlayer(player)
	if playerRigs[player] then
		restoreRig(playerRigs[player])
		playerRigs[player] = nil
	end
	if playerConns[player] then
		for _, c in ipairs(playerConns[player]) do
			if c and c.Connected then
				c:Disconnect()
			end
		end
		playerConns[player] = nil
	end
end

local function refreshAllPlayers()
	if enabled then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LocalPlayer or CONFIG.ApplyToAllPlayers then
				if plr.Character then
					task.spawn(buildRigForPlayer, plr, plr.Character)
				end
			end
		end
	else
		for plr, rig in pairs(playerRigs) do
			restoreRig(rig)
			playerRigs[plr] = nil
		end
	end
end

-- ============================================================================
-- '90s FIRST-PERSON VIEWMODEL (Doom-style 2D pixel arm + stepped bob + tool)
-- ============================================================================
local fpGui = nil
local fpArmLabel = nil
local fpToolIcon = nil
local fpSwingUntil = 0
local fpBobTime = 0

local function destroyFirstPersonViewmodel()
	if fpGui and fpGui.Parent then
		fpGui:Destroy()
	end
	fpGui = nil
	fpArmLabel = nil
	fpToolIcon = nil
end

local function ensureFirstPersonViewmodel()
	if fpGui and fpGui.Parent then return end
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return end

	fpGui = Instance.new("ScreenGui")
	fpGui.Name = "ESpritesRetroFP"
	fpGui.ResetOnSpawn = false
	fpGui.IgnoreGuiInset = true
	fpGui.DisplayOrder = -2
	fpGui.Enabled = false
	fpGui.Parent = pg

	fpArmLabel = Instance.new("ImageLabel")
	fpArmLabel.Name = "FPArm"
	fpArmLabel.BackgroundTransparency = 1
	fpArmLabel.BorderSizePixel = 0
	fpArmLabel.Image = fpArmUrl or ""
	fpArmLabel.ImageRectSize = Vector2.new(32, 32)
	fpArmLabel.ImageRectOffset = Vector2.new(0, 0)
	fpArmLabel.ScaleType = Enum.ScaleType.Fit
	fpArmLabel.SizeConstraint = Enum.SizeConstraint.RelativeYY
	fpArmLabel.AnchorPoint = Vector2.new(0.5, 1)
	fpArmLabel.Position = UDim2.fromScale(0.78, 1.03)
	fpArmLabel.Size = UDim2.fromScale(0.46, 0.46)
	fpArmLabel.ZIndex = 2
	pcall(function() fpArmLabel.ResampleMode = Enum.ResamplerMode.Pixelated end)
	fpArmLabel.Parent = fpGui

	fpToolIcon = Instance.new("ImageLabel")
	fpToolIcon.Name = "FPToolIcon"
	fpToolIcon.BackgroundTransparency = 1
	fpToolIcon.BorderSizePixel = 0
	fpToolIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	fpToolIcon.Position = UDim2.fromScale(0.28, 0.24)
	fpToolIcon.Size = UDim2.fromScale(0.48, 0.48)
	fpToolIcon.ScaleType = Enum.ScaleType.Fit
	fpToolIcon.ZIndex = 3
	fpToolIcon.Visible = false
	pcall(function() fpToolIcon.ResampleMode = Enum.ResamplerMode.Pixelated end)
	fpToolIcon.Parent = fpArmLabel
end

table.insert(connections, RunService.RenderStepped:Connect(function(dt)
	if not enabled then
		return
	end

	if hudHealthFill and hudHpText then
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			local maxHp = math.max(1, hum.MaxHealth)
			local hp = math.clamp(hum.Health, 0, maxHp)
			hudHealthFill.Size = UDim2.fromScale(hp / maxHp, 1)
			hudHpText.Text = "HP " .. tostring(math.floor(hp + 0.5))
		end
	end

	local camera = workspace.CurrentCamera
	local isFirstPerson = false
	if enabled and CONFIG.EnableFirstPersonViewmodel and camera then
		local camDist = (camera.CFrame.Position - camera.Focus.Position).Magnitude
		if camDist < 1.65 then
			isFirstPerson = true
		else
			local lc = LocalPlayer.Character
			local lHead = lc and lc:FindFirstChild("Head")
			if lHead and lHead:IsA("BasePart") and (camera.CFrame.Position - lHead.Position).Magnitude < 1.65 then
				isFirstPerson = true
			end
		end
	end

	if isFirstPerson and fpArmUrl then
		ensureFirstPersonViewmodel()
		if fpGui then
			fpGui.Enabled = true
			local lChar = LocalPlayer.Character
			local lHum = lChar and lChar:FindFirstChildOfClass("Humanoid")
			local moving = lHum and lHum.Health > 0 and lHum.MoveDirection.Magnitude > 0.05
			if moving then
				fpBobTime = fpBobTime + dt
			else
				fpBobTime = 0
			end
			-- Classic '90s stepped Doom figure-8 sway
			local steppedT = math.floor(fpBobTime * 10) / 10
			local bobX = moving and (math.cos(steppedT * 8) * 0.028) or 0
			local bobY = moving and (math.abs(math.sin(steppedT * 8)) * 0.042) or 0
			local baseX = (CONFIG.FirstPersonArmSide == "Left") and 0.22 or 0.78
			if fpArmLabel then
				fpArmLabel.ImageColor3 = localCustom.skinColor or Color3.fromRGB(255, 255, 85)
				fpArmLabel.ImageRectOffset = Vector2.new(0, 0)
				fpArmLabel.Position = UDim2.fromScale(baseX + bobX, 1.03 + bobY)
				fpArmLabel.Visible = (lHum ~= nil and lHum.Health > 0)
			end
			if fpToolIcon then
				local eqTool = lChar and lChar:FindFirstChildOfClass("Tool")
				local tid = ""
				if eqTool then pcall(function() tid = eqTool.TextureId end) end
				if type(tid) == "string" and tid ~= "" then
					fpToolIcon.Image = tid
					fpToolIcon.Visible = true
				else
					fpToolIcon.Visible = false
				end
			end
		end
	elseif fpGui then
		fpGui.Enabled = false
	end

	local fullCamLook = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
	local camLook = Vector3.new(fullCamLook.X, 0, fullCamLook.Z)
	local hasCamDir = camLook.Magnitude > 0.01
	if hasCamDir then
		camLook = camLook.Unit
	end

	if inTopView then
		if fullCamLook.Y > CONFIG.TopViewExitThreshold then
			inTopView = false
		end
	else
		if fullCamLook.Y < CONFIG.TopViewEnterThreshold then
			inTopView = true
		end
	end
	local isTopView = inTopView

	for _, rig in pairs(playerRigs) do
		local hrp = rig.hrp
		local humanoid = rig.humanoid
		local character = rig.character
		if hrp and hrp.Parent and humanoid and humanoid.Health > 0 and character then
			-- Enforce hiding on LocalPlayer accessories/parts every frame so vehicle seats never unhide hats
			if rig.player == LocalPlayer then
				if rig.billboard then rig.billboard.Enabled = not isFirstPerson end
				if rig.nameBillboard then rig.nameBillboard.Enabled = not isFirstPerson end
				for inst in pairs(rig.savedParts) do
					if inst and inst.Parent then
						if inst:IsA("BasePart") then
							inst.Transparency = 1
							inst.LocalTransparencyModifier = 1
						elseif inst:IsA("Decal") or inst:IsA("Texture") then
							inst.Transparency = 1
						end
					end
				end
			end
			if rig.nameBillboard and rig.healthBg and rig.healthFill then
				local maxHp = math.max(1, humanoid.MaxHealth)
				local pct = math.clamp(humanoid.Health / maxHp, 0, 1)
				rig.healthFill.Size = UDim2.fromScale(pct, 1)
				local hType = rig.origHealthDisplayType
				if hType == Enum.HumanoidHealthDisplayType.AlwaysOff then
					rig.healthBg.Visible = false
				elseif hType == Enum.HumanoidHealthDisplayType.AlwaysOn then
					rig.healthBg.Visible = true
				else
					rig.healthBg.Visible = (humanoid.Health < maxHp)
				end
				if isTopView then
					rig.nameBillboard.StudsOffset = Vector3.zero
					rig.nameBillboard.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
				else
					rig.nameBillboard.StudsOffset = Vector3.new(0, 4.1, 0)
					rig.nameBillboard.StudsOffsetWorldSpace = Vector3.zero
				end
			end
			if rig.ffFrame then
				local hasFF = (character:FindFirstChildOfClass("ForceField") ~= nil)
				rig.ffFrame.Visible = hasFF
				if hasFF then
					local pulse = 0.72 + math.abs(math.sin(os.clock() * 6)) * 0.16
					rig.ffFrame.BackgroundTransparency = pulse
				end
			end
			local equippedTool = character:FindFirstChildOfClass("Tool")
			local hasTool = applyToolVisuals(rig, equippedTool)

			local isSidePose = false
			local charLook = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
			local dot = -1
			local crossY = 0
			if hasCamDir and charLook.Magnitude > 0.01 then
				charLook = charLook.Unit
				dot = camLook:Dot(charLook)
				crossY = camLook:Cross(charLook).Y
			end

			if not isTopView then
				if dot < -0.65 then
					applySheetFrame(rig.headSheet or "Head", rig.head, rig.pixelFace and HEAD_FRAMES.BACK or HEAD_FRAMES.FRONT)
				elseif dot > 0.65 then
					applySheetFrame(rig.headSheet or "Head", rig.head, HEAD_FRAMES.BACK)
				elseif crossY > 0 then
					applySheetFrame(rig.headSheet or "Head", rig.head, HEAD_FRAMES.LEFT)
					isSidePose = true
				else
					applySheetFrame(rig.headSheet or "Head", rig.head, HEAD_FRAMES.RIGHT)
					isSidePose = true
				end
			end

			local isMoving = humanoid.MoveDirection.Magnitude > 0.05
			local state = humanoid:GetState()
			local isAirborne = (state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall)

			local steppedTime = 0
			local swing = 0
			local bob = 0
			if isMoving and not isAirborne then
				rig.animTime += dt
				local stepIndex = math.floor(rig.animTime * CONFIG.AnimFPS)
				steppedTime = stepIndex / CONFIG.AnimFPS
				swing = math.sin(steppedTime * 12) * 0.025
				bob = math.abs(math.sin(steppedTime * 12)) * 0.018
			else
				rig.animTime = 0
			end

			rig.leftArm.Rotation = 0
			rig.rightArm.Rotation = 0
			rig.head.Rotation = 0

			local jumpArmRaise = isAirborne and -0.16 or 0
			local toolArmRaise = hasTool and -0.13 or 0

			if isTopView then
				rig.billboard.Size = UDim2.fromScale(CONFIG.TopViewBillboardSize, CONFIG.TopViewBillboardSize)
				rig.billboard.StudsOffset = Vector3.zero
				rig.billboard.StudsOffsetWorldSpace = CONFIG.TopViewWorldOffset
				rig.root.Rotation = 0
				rig.legs.Visible = false
				rig.rightArm.Visible = true
				rig.leftArm.ZIndex = 3
				rig.torso.ScaleType = Enum.ScaleType.Fit
				rig.torso.Size = rig.torsoFillMode
					and UDim2.fromScale(0.45, 0.17)
					or UDim2.fromScale(0.50, 0.38)

				applySheetFrame(rig.headSheet or "Head", rig.head, HEAD_FRAMES.TOP)
				applySheetFrame("Torso", rig.torso, TORSO_FRAMES.TOP)
				applySheetFrame(rig.armsSheet or "Arms", rig.leftArm, ARM_FRAMES.TOP)
				applySheetFrame(rig.armsSheet or "Arms", rig.rightArm, ARM_FRAMES.TOP)

				rig.leftArm.ScaleType = Enum.ScaleType.Stretch
				rig.rightArm.ScaleType = Enum.ScaleType.Stretch
				rig.leftArm.Size = UDim2.fromScale(0.34, 0.28)
				rig.rightArm.Size = UDim2.fromScale(0.34, 0.28)

				if rig.pixelCollar then
					rig.pixelCollar.Visible = true
					rig.pixelCollar.Size = UDim2.fromScale(0.95, 0.95)
					rig.pixelCollar.ImageRectOffset = Vector2.new(96, 0)
				end
				if rig.pixelBelt then rig.pixelBelt.Visible = false end
				if rig.pixelFace then rig.pixelFace.Visible = false end
				if rig.pixelShades then
					rig.pixelShades.Visible = true
					rig.pixelShades.Position = UDim2.fromScale(0.531, 0.24)
					rig.pixelShades.Size = UDim2.fromScale(0.62, 0.16)
					rig.pixelShades.ImageRectOffset = Vector2.new(96, 0)
				end
				if rig.pixelHat then
					local hm = HAT_META[rig.hatStyle] or DEFAULT_HAT_META
					rig.pixelHat.Visible = true
					rig.pixelHat.ImageRectOffset = Vector2.new(3 * 40, 0)
					rig.pixelHat.AnchorPoint = Vector2.new(0.5, 0.5)
					rig.pixelHat.Position = UDim2.fromScale(0.531, 0.484)
					rig.pixelHat.ScaleType = Enum.ScaleType.Stretch
					rig.pixelHat.Size = hm.tSize
				end
				rig.head.Position = UDim2.fromScale(0.50, 0.49)
				rig.torso.Position = UDim2.fromScale(0.50, 0.49)

				if hasTool then
					if dot > 0.65 then
						-- Facing away/forward (-Y on screen)
						rig.leftArm.Position = UDim2.fromScale(0.312, 0.49 + swing)
						rig.rightArm.Position = UDim2.fromScale(0.858, 0.42)
						rig.toolIcon.Position = UDim2.fromScale(0.77, 0.25)
					elseif dot < -0.65 then
						-- Facing toward camera (+Y on screen)
						rig.leftArm.Position = UDim2.fromScale(0.312, 0.49 + swing)
						rig.rightArm.Position = UDim2.fromScale(0.858, 0.56)
						rig.toolIcon.Position = UDim2.fromScale(0.77, 0.73)
					elseif crossY > 0 then
						-- Facing left (-X on screen)
						rig.leftArm.Position = UDim2.fromScale(0.24, 0.49)
						rig.rightArm.Position = UDim2.fromScale(0.858, 0.49 - swing)
						rig.toolIcon.Position = UDim2.fromScale(0.11, 0.49)
					else
						-- Facing right (+X on screen)
						rig.leftArm.Position = UDim2.fromScale(0.312, 0.49 + swing)
						rig.rightArm.Position = UDim2.fromScale(0.93, 0.49)
						rig.toolIcon.Position = UDim2.fromScale(0.90, 0.49)
					end
				else
					rig.leftArm.Position = UDim2.fromScale(0.312, 0.49 + swing)
					rig.rightArm.Position = UDim2.fromScale(0.858, 0.49 - swing)
				end
			elseif isSidePose then
				rig.billboard.Size = UDim2.fromScale(CONFIG.BillboardWidth, CONFIG.BillboardHeight)
				rig.billboard.StudsOffset = CONFIG.StudsOffset
				rig.billboard.StudsOffsetWorldSpace = Vector3.zero
				rig.root.Rotation = 0
				rig.legs.Visible = true
				if rig.legDivider then
					rig.legDivider.Visible = false
				end
				rig.rightArm.Visible = false
				rig.leftArm.ZIndex = isAirborne and 5 or 3
				rig.leftArm.ScaleType = Enum.ScaleType.Fit
				rig.rightArm.ScaleType = Enum.ScaleType.Fit
				rig.leftArm.Size = UDim2.fromScale(0.38, 0.38)
				rig.rightArm.Size = UDim2.fromScale(0.38, 0.38)
				rig.torso.ScaleType = Enum.ScaleType.Stretch
				rig.torso.Size = UDim2.fromScale(0.24, 0.38)
				rig.legs.Size = rig.legsFillMode
					and UDim2.fromScale(0.24, 0.36)
					or UDim2.fromScale(0.50, 0.38)

				applySheetFrame("Torso", rig.torso, TORSO_FRAMES.NORMAL)
				applySheetFrame(rig.armsSheet or "Arms", rig.leftArm, ARM_FRAMES.IDLE)
				applySheetFrame("SideLeg", rig.legs, 0)

				local sideArmY = hasTool and (0.49 + math.min(jumpArmRaise, toolArmRaise)) or (0.49 + swing * 0.6 + jumpArmRaise)
				if rig.pixelCollar then
					rig.pixelCollar.Visible = true
					rig.pixelCollar.Size = UDim2.fromScale(0.95, 0.96)
					rig.pixelCollar.ImageRectOffset = Vector2.new(32, 0)
				end
				if rig.pixelBelt then
					rig.pixelBelt.Visible = true
					rig.pixelBelt.Size = rig.legsFillMode and UDim2.fromScale(0.95, 0.95) or UDim2.fromScale(0.43, 0.96)
					rig.pixelBelt.ImageRectOffset = Vector2.new(32, 0)
				end
				if rig.pixelFace then
					local isLeft = (crossY > 0)
					rig.pixelFace.Visible = true
					rig.pixelFace.ImageRectOffset = Vector2.new((isLeft and 1 or 2) * 32, 0)
					rig.pixelFace.Position = UDim2.fromScale(0.531, 0.48)
					applySheetFrame(rig.headSheet or "Head", rig.head, HEAD_FRAMES.BACK)
				end
				if rig.pixelShades then
					local isLeft = (crossY > 0)
					rig.pixelShades.Visible = true
					rig.pixelShades.Position = UDim2.fromScale(0.531, 0.371)
					rig.pixelShades.Size = UDim2.fromScale(0.625, 0.23)
					rig.pixelShades.ImageRectOffset = Vector2.new((isLeft and 1 or 2) * 32, 0)
				end
				if rig.pixelHat then
					local isLeft = (crossY > 0)
					local hm = HAT_META[rig.hatStyle] or DEFAULT_HAT_META
					rig.pixelHat.Visible = true
					rig.pixelHat.ImageRectOffset = Vector2.new((isLeft and 1 or 2) * 40, 0)
					rig.pixelHat.AnchorPoint = Vector2.new(0.5, 1)
					rig.pixelHat.ScaleType = hm.stretch and Enum.ScaleType.Stretch or Enum.ScaleType.Fit
					rig.pixelHat.Position = hm.sPos
					rig.pixelHat.Size = hm.sSize
				end
				rig.head.Position = UDim2.fromScale(0.50, 0.20 - bob)
				rig.torso.Position = UDim2.fromScale(0.50, 0.49 - bob)
				rig.leftArm.Position = UDim2.fromScale(0.405, sideArmY)
				rig.legs.Position = UDim2.fromScale(0.50, 0.77 - bob * 0.5)
				rig.toolIcon.Position = UDim2.fromScale(0.55, sideArmY - 0.14)
			else
				rig.billboard.Size = UDim2.fromScale(CONFIG.BillboardWidth, CONFIG.BillboardHeight)
				rig.billboard.StudsOffset = CONFIG.StudsOffset
				rig.billboard.StudsOffsetWorldSpace = Vector3.zero
				rig.root.Rotation = 0
				rig.legs.Visible = true
				if rig.legDivider then
					rig.legDivider.Visible = true
				end
				rig.rightArm.Visible = true
				rig.leftArm.ZIndex = 3
				rig.leftArm.ScaleType = Enum.ScaleType.Fit
				rig.rightArm.ScaleType = Enum.ScaleType.Fit
				rig.leftArm.Size = UDim2.fromScale(0.38, 0.38)
				rig.rightArm.Size = UDim2.fromScale(0.38, 0.38)
				rig.torso.ScaleType = Enum.ScaleType.Fit
				rig.torso.Size = rig.torsoFillMode
					and UDim2.fromScale(0.45, 0.38)
					or UDim2.fromScale(0.50, 0.38)
				rig.legs.Size = rig.legsFillMode
					and UDim2.fromScale(0.45, 0.38)
					or UDim2.fromScale(0.50, 0.38)

				applySheetFrame("Torso", rig.torso, TORSO_FRAMES.NORMAL)
				applySheetFrame(rig.armsSheet or "Arms", rig.leftArm, ARM_FRAMES.IDLE)
				applySheetFrame(rig.armsSheet or "Arms", rig.rightArm, ARM_FRAMES.IDLE)
				applySheetFrame("Legs", rig.legs, 0)

				local rightArmY = hasTool and (0.49 + math.min(jumpArmRaise, toolArmRaise)) or (0.49 - swing + jumpArmRaise)
				local isBack = (dot > 0.65)
				if rig.pixelCollar then
					rig.pixelCollar.Visible = (not isBack) or (rig.shirtStyle ~= "Tie")
					rig.pixelCollar.Size = rig.torsoFillMode and UDim2.fromScale(0.95, 0.95) or UDim2.fromScale(0.88, 0.96)
					rig.pixelCollar.ImageRectOffset = Vector2.new(isBack and 64 or 0, 0)
				end
				if rig.pixelBelt then
					rig.pixelBelt.Visible = true
					rig.pixelBelt.Size = rig.legsFillMode and UDim2.fromScale(0.95, 0.95) or UDim2.fromScale(0.88, 0.96)
					rig.pixelBelt.ImageRectOffset = Vector2.new(0, 0)
				end
				if rig.pixelFace then rig.pixelFace.Visible = not isBack; rig.pixelFace.ImageRectOffset = Vector2.new(0, 0); rig.pixelFace.Position = UDim2.fromScale(0.531, 0.48) end
				if rig.pixelShades then
					rig.pixelShades.Visible = not isBack
					rig.pixelShades.Position = UDim2.fromScale(0.531, 0.371)
					rig.pixelShades.Size = UDim2.fromScale(0.58, 0.22)
					rig.pixelShades.ImageRectOffset = Vector2.new(0, 0)
				end
				if rig.pixelHat then
					local hm = HAT_META[rig.hatStyle] or DEFAULT_HAT_META
					rig.pixelHat.Visible = true
					rig.pixelHat.ImageRectOffset = Vector2.new((isBack and 4 or 0) * 40, 0)
					rig.pixelHat.AnchorPoint = Vector2.new(0.5, 1)
					rig.pixelHat.ScaleType = hm.stretch and Enum.ScaleType.Stretch or Enum.ScaleType.Fit
					rig.pixelHat.Position = hm.fPos
					rig.pixelHat.Size = hm.fSize
				end
				rig.head.Position = UDim2.fromScale(0.50, 0.20 - bob)
				rig.torso.Position = UDim2.fromScale(0.50, 0.49 - bob)
				rig.leftArm.Position = UDim2.fromScale(0.09, 0.49 + swing + jumpArmRaise)
				rig.rightArm.Position = UDim2.fromScale(0.72, rightArmY)
				rig.legs.Position = UDim2.fromScale(0.50, 0.77 - bob * 0.5)
				rig.toolIcon.Position = UDim2.fromScale(0.84, rightArmY - 0.14)
			end
		end
	end
end))


-- ============================================================================
-- PIXEL PARTICLE EFFECTS (Sparkles, Smoke, Fire)
-- ============================================================================
local FX_SPARKLE_B64 = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAmUlEQVR42u3Y0Q2AIAxAQTCuCEPqkLgBhA+qkXsLSC6WWFOSJEm7lqMf2Fpp3QPlO/RMx+5vAAAAAAAAAAAAAAC7QNgu0Aa7QLYLAADwoztgNPPDAy6+E4wAAHfAaIbL5Axfi49cJ++Q/j9GIwAAAAAAAHwH2AWMAAB3QEz+CRoBAJ/qjH9k9QYAAAAAAAAAAAAAACBJkvReDzmKGbNs5QhkAAAAAElFTkSuQmCC"
local FX_SMOKE_B64 = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAtklEQVR42u3ZwRHCIBBG4ehYSlqCItmW6AXvHkQFFc33rkwI82b/zSbZNgAAAABH5DR7w9ZaHbk+Iu6u55z3mec9H70CCNADFs98j9GeIAIE6AG/lfnefhGxqwACCHiYy7tvMDvzKoAAAtaeA76d+WffDUSAAHPAfz/nVQABBMztAatlfvQ8IkAAAQQQQIDvAa9TSqmfPPDofwAVQAABc3vALSml2lkfmu1HM68CCCAAAAAAALYrw7o1Vc28wp8AAAAASUVORK5CYII="
local FX_FIRE_B64 = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAA0UlEQVR42u3bUQ6DIBREUWncoixSF2l3UNIUBhvO/JIYvGHmPRDLFtZ9HPen8XJdJTmf17a4AFgdQJnt+eYEB2cCCwAgA57l+XQmsAAAMiDs+bMxXrOZwAIAAAAAAADoAybW/ZYG9wUsAMDi2rs/8Rz8vGoFAABAsg+I1/1wX8ACAOgDHlb3w30BCwAgA9KmHVz4rQAAAAAAAAAA6HYe8PX5wOTzAN8FWACAyXuB+ldbASsAAH3Ajxp9N7j5Au4JsgAAUzMgnQn+F2ABAIiIuukNEEwuIjPNfdYAAAAASUVORK5CYII="

local fxSparkleUrl = loadDOSEmbedded("dos_fx_sparkles.png", FX_SPARKLE_B64)
local fxSmokeUrl = loadDOSEmbedded("dos_fx_smoke.png", FX_SMOKE_B64)
local fxFireUrl = loadDOSEmbedded("dos_fx_fire.png", FX_FIRE_B64)

local savedLegacyParticles = {} -- Instance -> Enabled
local createdPixelEmitters = {}

local function isInsidePlayerCharacter(inst)
	local model = inst:FindFirstAncestorOfClass("Model")
	while model do
		if Players:GetPlayerFromCharacter(model) then
			return true
		end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function replaceLegacyParticle(inst)
	if not enabled or not CONFIG.ReplaceParticles then return end
	if not inst or not inst.Parent then return end
	if savedLegacyParticles[inst] ~= nil then return end
	if isInsidePlayerCharacter(inst) then
		savedLegacyParticles[inst] = inst.Enabled
		inst.Enabled = false
		return
	end

	if inst:IsA("Sparkles") and fxSparkleUrl then
		savedLegacyParticles[inst] = inst.Enabled
		inst.Enabled = false
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "ESpritesPixelSparkles"
		pe.Texture = fxSparkleUrl
		pe.Color = ColorSequence.new(inst.SparkleColor)
		pe.LightEmission = 1
		pe.Lifetime = NumberRange.new(0.4, 0.9)
		pe.Rate = 18
		pe.Speed = NumberRange.new(2, 5)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(1, 0),
		})
		pe.Parent = inst.Parent
		table.insert(createdPixelEmitters, pe)
	elseif inst:IsA("Smoke") and fxSmokeUrl then
		savedLegacyParticles[inst] = inst.Enabled
		inst.Enabled = false
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "ESpritesPixelSmoke"
		pe.Texture = fxSmokeUrl
		pe.Color = ColorSequence.new(inst.Color)
		pe.LightEmission = 0
		pe.Lifetime = NumberRange.new(1.5, 3.0)
		pe.Rate = 12
		pe.Speed = NumberRange.new(2, 5)
		pe.SpreadAngle = Vector2.new(35, 35)
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, math.max(0.8, inst.Size * 0.6)),
			NumberSequenceKeypoint.new(1, math.max(1.8, inst.Size * 1.4)),
		})
		pe.Parent = inst.Parent
		table.insert(createdPixelEmitters, pe)
	elseif inst:IsA("Fire") and fxFireUrl then
		savedLegacyParticles[inst] = inst.Enabled
		inst.Enabled = false
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "ESpritesPixelFire"
		pe.Texture = fxFireUrl
		pe.LightEmission = 1
		pe.Lifetime = NumberRange.new(0.45, 0.9)
		pe.Rate = 24
		pe.Speed = NumberRange.new(3, 6)
		pe.SpreadAngle = Vector2.new(25, 25)
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, math.max(0.9, inst.Size * 0.28)),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		pe.Parent = inst.Parent
		table.insert(createdPixelEmitters, pe)
	end
end

local function enablePixelParticles()
	if not CONFIG.ReplaceParticles then return end
	task.spawn(function()
		for _, desc in ipairs(Workspace:GetDescendants()) do
			if not enabled then return end
			if desc:IsA("Sparkles") or desc:IsA("Smoke") or desc:IsA("Fire") or desc:IsA("ParticleEmitter") then
				if desc.Name:sub(1, 13) ~= "ESpritesPixel" then
					if desc:IsA("ParticleEmitter") then
						if isInsidePlayerCharacter(desc) and savedLegacyParticles[desc] == nil then
							savedLegacyParticles[desc] = desc.Enabled
							desc.Enabled = false
						end
					else
						replaceLegacyParticle(desc)
					end
				end
			end
		end
	end)
end

local function disablePixelParticles()
	for _, pe in ipairs(createdPixelEmitters) do
		if pe and pe.Parent then pe:Destroy() end
	end
	table.clear(createdPixelEmitters)
	for inst, origEnabled in pairs(savedLegacyParticles) do
		if inst and inst.Parent then
			pcall(function() inst.Enabled = origEnabled end)
		end
	end
	table.clear(savedLegacyParticles)
end

-- ============================================================================
-- INITIALIZATION & CLEANUP
-- ============================================================================
for _, plr in ipairs(Players:GetPlayers()) do
	hookPlayer(plr)
end
table.insert(connections, Players.PlayerAdded:Connect(hookPlayer))
table.insert(connections, Players.PlayerRemoving:Connect(unhookPlayer))

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({ resolvedSheets.SideLeg.url })
	end)
end)

task.spawn(enableWorldAudioAndImages)
enableDOSWorldTextures()
task.spawn(enableFlatLightingAndNoShadows)
createRetroHUD()

for _, service in ipairs({ Workspace, SoundService, Players }) do
	table.insert(connections, service.DescendantAdded:Connect(function(desc)
		if not enabled then return end
		if desc:IsA("Sound") then
			applyPixelAudioToSound(desc)
		elseif desc:IsA("ImageLabel") or desc:IsA("ImageButton") or desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("UICorner") then
			applyPixelResample(desc)
		end
	end))
end

table.insert(connections, Workspace.DescendantAdded:Connect(function(desc)
	if not enabled then return end
	if CONFIG.ReplaceExplosions and desc:IsA("Explosion") then
		spawnPixelExplosion(desc)
	end
	if CONFIG.EnableDOSWorldTextures and desc:IsA("BasePart") then
		task.defer(hookDOSPart, desc)
	end
	if CONFIG.RemoveAllShadowsAndLights then
		suppressLightOrShadow(desc)
	end
	if CONFIG.ReplaceParticles and (desc:IsA("Sparkles") or desc:IsA("Smoke") or desc:IsA("Fire") or desc:IsA("ParticleEmitter")) then
		if desc.Name:sub(1, 13) ~= "ESpritesPixel" then
			if desc:IsA("ParticleEmitter") then
				task.defer(function()
					if enabled and desc and desc.Parent and isInsidePlayerCharacter(desc) and savedLegacyParticles[desc] == nil then
						savedLegacyParticles[desc] = desc.Enabled
						desc.Enabled = false
					end
				end)
			else
				task.defer(replaceLegacyParticle, desc)
			end
		end
	end
end))

table.insert(connections, Lighting.Changed:Connect(function()
	if enabled and CONFIG.RemoveAllShadowsAndLights and not lightingUpdating then
		task.defer(function()
			applyFlatLightingProps()
			updateRetroSkyboxAndAmbient()
		end)
	end
end))
table.insert(connections, Lighting.DescendantAdded:Connect(function(desc)
	if enabled then suppressLightOrShadow(desc) end
end))

pcall(function()
	table.insert(connections, TextChatService.MessageReceived:Connect(function(textChatMessage)
		if textChatMessage and textChatMessage.TextSource then
			local plr = Players:GetPlayerByUserId(textChatMessage.TextSource.UserId)
			if plr then
				pushPixelChatBubble(plr, textChatMessage.Text)
			end
		end
	end))
end)

if CONFIG.EnableToggle then
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == CONFIG.ToggleKey then
			enabled = not enabled
			refreshAllPlayers()
			if enabled then
				pcall(function()
					UserSettings():GetService("UserGameSettings").RotationType = Enum.RotationType.MovementRelative
				end)
				task.spawn(enableWorldAudioAndImages)
				enableDOSWorldTextures()
				task.spawn(enableFlatLightingAndNoShadows)
				if CONFIG.EnablePixelChatBubbles then setRobloxDefaultBubbles(false) end
				createRetroHUD()
				enablePixelParticles()
			else
				disableWorldAudioAndImages()
				disableDOSWorldTextures()
				disableFlatLightingAndNoShadows()
				for plr in pairs(playerChatStacks) do destroyPlayerChatStack(plr) end
				if savedBubbleChatEnabled ~= nil then setRobloxDefaultBubbles(savedBubbleChatEnabled) end
				destroyRetroHUD()
				destroyFirstPersonViewmodel()
				disablePixelParticles()
			end
		end
	end))
end

RunService:BindToRenderStep(CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
	if not enabled or not CONFIG.ChoppyZoom or CONFIG.ZoomStepStuds <= 0 then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local focusPos = camera.Focus.Position
	local offset = camera.CFrame.Position - focusPos
	local dist = offset.Magnitude
	if dist <= 1.5 then return end
	local targetDist = math.max(CONFIG.ZoomStepStuds, math.floor(dist / CONFIG.ZoomStepStuds + 0.5) * CONFIG.ZoomStepStuds)
	camera.CFrame = CFrame.lookAt(focusPos + offset.Unit * targetDist, focusPos)
end)

_G.ESpritesCleanup = function()
	pcall(function() RunService:UnbindFromRenderStep(CAMERA_BIND_NAME) end)
	for _, conn in ipairs(connections) do
		if conn and conn.Connected then conn:Disconnect() end
	end
	table.clear(connections)
	for plr in pairs(playerConns) do unhookPlayer(plr) end
	for plr, rig in pairs(playerRigs) do
		restoreRig(rig)
		playerRigs[plr] = nil
	end
	for bb, anchor in pairs(activeExplosions) do
		if bb and bb.Parent then bb:Destroy() end
		if anchor and anchor.Parent then anchor:Destroy() end
	end
	table.clear(activeExplosions)
	disableWorldAudioAndImages()
	disableDOSWorldTextures()
	disableFlatLightingAndNoShadows()
	for plr in pairs(playerChatStacks) do destroyPlayerChatStack(plr) end
	if savedBubbleChatEnabled ~= nil then setRobloxDefaultBubbles(savedBubbleChatEnabled) end
	destroyRetroHUD()
	destroyFirstPersonViewmodel()
	disablePixelParticles()
end
