"""
Seed a sample pro-player analysis document into Firestore.
This creates a "reference" analysis that appears at the top of the history tab.
"""
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timezone

# Initialize with Application Default Credentials (uses gcloud auth)
firebase_admin.initialize_app(options={
    'projectId': 'minton-smash-cv-app',
})

db = firestore.client()

sample_doc = {
    'userId': '__sample__',
    'isSample': True,
    'playerName': 'Lee Zii Jia',
    'playerInfo': '말레이시아 배드민턴 국가대표 | 세계랭킹 TOP 5',
    'videoUrl': 'gs://minton-smash-cv-app.firebasestorage.app/samples/pro_smash_lee_zii_jia.mp4',
    'status': 'completed',
    'createdAt': datetime.now(timezone.utc).isoformat(),
    'completedAt': datetime.now(timezone.utc).isoformat(),
    'result': {
        'overallScore': 95.2,
        'smashSpeed': 408,
        'impactAngle': 168.5,
        'elbowAngle': 172.0,
        'shoulderAngle': 175.0,
        'wristSnapSpeed': 92,
        'footwork': 96.0,
        'hipRotation': 48.5,
    },
    'coaching': {
        'summary': 'Lee Zii Jia 선수의 스매시는 교과서적인 폼을 보여줍니다. '
                   '임팩트 시 팔꿈치가 거의 완전히 펴져 있고(172°), 어깨 회전이 충분하며(175°), '
                   '히프 로테이션(48.5°)이 파워의 핵심입니다. '
                   '특히 임팩트 각도 168.5°는 최적의 타점을 유지하고 있음을 보여줍니다.',
        'keyPoints': [
            '임팩트 순간 팔꿈치 완전 신전 (172°) — 최대 파워 전달',
            '어깨 회전 175° — 풀 로테이션으로 운동 에너지 극대화',
            '히프 로테이션 48.5° — 하체에서 상체로 파워 체인 연결',
            '스매시 속도 408 km/h — 프로 남자 단식 평균 이상',
            '풋워크 96점 — 안정적 스탠스와 빠른 리커버리',
        ],
        'drills': [
            '셔도우 풋워크: 스매시 후 센터 복귀 반복 (3세트 x 20회)',
            '히프 로테이션 드릴: 메디신볼 회전 던지기 (3세트 x 15회)',
            '손목 스냅 강화: 라켓 무게추 부착 스윙 (2세트 x 30회)',
            '연속 점프 스매시: 셔틀콕 피더와 연속 10회 스매시',
        ],
    },
}

doc_ref = db.collection('sampleAnalyses').document('lee_zii_jia_smash')
doc_ref.set(sample_doc)
print(f"Sample analysis created: {doc_ref.path}")
print("Done!")
