"""Deterministic coordinate source for five Chapter 2 proposal maps.
This generates design data only; never writes shipping content.
"""
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent

def walk(*corners):
    out=[list(corners[0])]
    for target in corners[1:]:
        x,y=out[-1];tx,ty=target
        assert x==tx or y==ty
        while (x,y)!=(tx,ty):
            x+=(tx>x)-(tx<x);y+=(ty>y)-(ty<y);out.append([x,y])
    return out

def zone(name,purpose,cells):return {'name':name,'purpose':purpose,'buildCells':[list(c) for c in cells]}

def define(stage,name,size,segments,pairs,zones,intent,role):
    path=sum(segments,[]);build=[c for z in zones for c in z['buildCells']];cols,rows=size
    assert len(set(map(tuple,path)))==len(path)
    assert len(set(map(tuple,build)))==len(build)
    assert not set(map(tuple,path))&set(map(tuple,build))
    assert all(0<=x<cols and 0<=y<rows for x,y in path+build)
    tiles=['blocked']*(cols*rows)
    for x,y in path:tiles[y*cols+x]='path'
    for x,y in build:tiles[y*cols+x]='build'
    for kind,cell in [('spawn',path[0]),('core',path[-1])]:tiles[cell[1]*cols+cell[0]]=kind
    portals=[];gaps=[]
    for i,color in enumerate(pairs):
        a,b=segments[i][-1],segments[i+1][0]
        portals.append({'color':color,'entrance':a,'exit':b})
        gap=walk(a,b)[1:-1]
        assert all(tiles[y*cols+x]=='blocked' for x,y in gap)
        gaps.extend(gap)
    jumps={(tuple(p['entrance']),tuple(p['exit'])) for p in portals}
    assert all(abs(a[0]-b[0])+abs(a[1]-b[1])==1 or (tuple(a),tuple(b)) in jumps for a,b in zip(path,path[1:]))
    return {'chapterStage':f'2-{stage-10}','progressionOrdinal':stage,'name':name,'role':role,'intent':intent,
            'columns':cols,'rows':rows,'tileTheme':'chapterTwoRift','tiles':tiles,'path':path,'buildCells':build,
            'pathTiles':len(path),'travelEdges':len(path)-1,'walkingEdges':sum(len(s)-1 for s in segments),
            'walkingSegments':[len(s)-1 for s in segments], 'teleportPairs':portals,'portalGapCells':gaps,'tacticalZones':zones}

maps=[
 define(16,'갈라진 순례길',(9,11),[walk((1,1),(6,1),(6,5),(3,5),(3,8),(7,8),(7,10))],[],[
  zone('상단 초입','넓은 첫 직선에서 보호막을 벗기되 후반 투자 여력을 남긴다.',[(2,2),(3,2),(4,2),(5,2),(4,3),(5,3),(7,2)]),
  zone('중앙 안쪽 굽이','방향이 바뀌는 두 구간을 함께 커버한다.',[(5,4),(7,4),(2,4),(2,5),(2,6),(4,6),(5,6)]),
  zone('하단 마무리','늦게 도착하는 보호막·보스 잔여 체력을 긴 후반에서 정리한다.',[(4,7),(5,7),(6,7),(6,9),(8,8),(8,9)]),
 ],'큰 굽이 두 곳과 하단 직선으로 이어지는 완만한 길. 초입·중앙·후방에 화력을 나누며 챕터 2 후반의 보호막 대응을 복습한다.','no-portal-long-route'),
 define(17,'맞은편 파수대',(10,11),[walk((1,1),(1,4),(4,4)),walk((8,4),(8,8),(5,8),(5,6),(2,6),(2,9))],['blue'],[
  zone('입구 전초','짧은 전반 6칸에서 첫 대응과 보호막 감소를 맡는다.',[(2,1),(2,2),(3,2),(4,2),(2,3),(3,3),(4,3),(0,3)]),
  zone('출구 방벽','순간이동 직후 오른쪽 세로길에서 빠른 적을 붙잡는다.',[(9,4),(9,5),(9,6),(7,5),(7,6),(7,7)]),
  zone('복귀 방어선','하단에서 왼쪽 코어로 돌아오는 2차 교전을 맡는다.',[(6,7),(6,9),(4,7),(3,7),(3,8),(3,9)]),
 ],'위쪽 전초와 아래쪽 본대가 청색 포탈로 연결된다. 입구와 출구 사이 세 칸은 지형 자체가 없고 전후 건설 구역도 이어 붙이지 않는다.','blue-separated-zones'),
 define(18,'수정의 귀환로',(10,11),[walk((8,1),(5,1),(5,3)),walk((1,3),(1,7),(4,7),(4,5),(7,5),(7,9),(5,9))],['orange'],[
  zone('상단 유도부','짧은 진입부에 최소 대응을 두고 주력은 출구 이후에 배치한다.',[(6,2),(7,2),(8,2),(6,3),(4,1)]),
  zone('출구 연속 교전','출구의 긴 세로길과 첫 복귀 굽이를 함께 공격한다.',[(2,4),(3,4),(2,5),(2,6),(3,6),(3,8),(4,8)]),
  zone('수정 안쪽 회랑','중앙 S자와 코어 앞 잔여 적을 이어서 처리한다.',[(5,8),(6,8),(6,6),(6,7),(8,6),(8,7),(8,8),(8,9)]),
 ],'상단의 짧은 유도부에서 주황 출구로 이동하면 18칸의 연속 교전이 시작된다. 출구를 지나 여러 굽이에서 같은 공격권을 재방문한다.','orange-sustained-exit'),
 define(19,'세 겹의 회랑',(10,11),[walk((1,1),(1,8),(4,8),(4,2),(7,2),(7,8))],[],[
  zone('첫 번째 공유 사선','첫 하행과 중앙 상행을 양쪽에서 함께 커버한다.',[(2,2),(3,2),(2,3),(3,3),(2,5),(3,5),(2,6),(3,6),(2,7),(3,7)]),
  zone('두 번째 공유 사선','중앙 상행과 마지막 하행의 겹치는 교전 시간을 활용한다.',[(5,3),(6,3),(5,4),(6,4),(5,6),(6,6),(5,7),(6,7)]),
  zone('후방 보조','마지막 세로길의 빠른 적 누수를 보완한다.',[(8,4),(8,7)]),
 ],'세 개의 평행 세로길을 한 경로가 차례로 지난다. 두 중앙 건설띠는 인접 경로를 동시에 겨냥할 수 있어 집중 투자와 후방 보완을 비교한다.','parallel-concentrated-fire'),
 define(20,'균열의 세 문턱',(11,12),[walk((1,1),(4,1),(4,4)),walk((8,4),(8,5),(9,5),(9,8),(8,8)),walk((3,8),(1,8),(1,10),(5,10),(5,9))],['blue','orange'],[
  zone('첫 문턱','상단 초입 6칸에서 기본 보호막 대응을 준비한다.',[(2,2),(3,2),(3,3),(2,3),(3,4),(5,1),(5,2)]),
  zone('중간 섬','청색 출구부터 주황 입구까지 6칸의 짧은 핵심 교전을 맡는다.',[(9,3),(8,3),(7,5),(7,6),(8,6),(8,7)]),
  zone('마지막 섬','두 번째 출구 이후 9칸에서 보스와 누적 후속 적을 마무리한다.',[(2,9),(3,9),(4,9),(2,7),(3,7),(6,10),(6,9)]),
 ],'청색·주황 두 전송으로 세 개의 독립 암반을 순회한다. 세 구역에 화력을 배분하는 운영을 의도하며, 두 출구 대응과 후반 자원 배분을 종합한다.','two-portals-three-islands'),
]
output={'status':'proposal-map-and-round-design','shippingContentModified':False,
 'numbering':'chapterStage 2-6..2-10 / progressionOrdinal 16..20 are logical expansion order, not shipping stage IDs',
 'coordinateConvention':'zero-based [column,row], origin top-left','maps':maps}
(HERE/'maps.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
for m in maps:print(m['chapterStage'],m['name'],'path',m['pathTiles'],'walk',m['walkingSegments'],'build',len(m['buildCells']))
