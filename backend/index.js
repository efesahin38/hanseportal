process.env.TZ = 'Europe/Berlin';
const express = require('express');
const cors = require('cors');
const supabase = require('./supabaseClient');
const reporter = require('./reporter');
const admin = require('firebase-admin');
require('dotenv').config();

// Firebase Admin Init
let serviceAccount;
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} else {
  serviceAccount = require('./serviceAccountKey.json');
}
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Global Log Middleware
app.use((req, res, next) => {
  console.log(`[HTTP] ${req.method} ${req.url} - ${new Date().toISOString()}`);
  next();
});

app.post('/api/debug', (req, res) => {
  console.log('[FLUTTER-DEBUG]', req.body.log);
  res.json({ok: true});
});

// Otomatik mail sistemi (cron)
reporter.startCronJobs();

// ============================================================
// AUTH
// ============================================================

// POST /api/auth/login
app.post('/api/auth/login', async (req, res) => {
  try {
    const { id, pin_code } = req.body;
    if (!id || !pin_code) return res.status(400).json({ error: 'ID ve PIN zorunludur.' });

    const { data: user, error } = await supabase
      .from('users')
      .select('id, name, role, company_id, email')
      .eq('id', id)
      .eq('pin_code', pin_code)
      .single();

    if (error || !user) return res.status(401).json({ error: 'Hatalı ID veya PIN. Lütfen tekrar deneyin.' });

    res.json({ user });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// POST /api/users/:id/fcm-token - Firebase token kaydet / sil
app.post('/api/users/:id/fcm-token', async (req, res) => {
  try {
    const { id } = req.params;
    const { fcm_token } = req.body;
    
    console.log(`[FCM-TOKEN] Gelen token kaydetme isteği - User: ${id}, Token: ${fcm_token ? fcm_token.substring(0, 15) + '...' : 'NULL'}`);

    if (!fcm_token || fcm_token.trim() === '') {
      // Çıkış yaparken token'ı silmek için
      await supabase.from('users').update({ fcm_token: null }).eq('id', id);
      console.log(`[FCM-TOKEN] User ${id} token'ı silindi.`);
      return res.json({ message: 'Token silindi.' });
    }

    // Aynı cihazdan (token'dan) başka biri giriş yapmışsa, önce eski sahibinden bu token'ı sil ki karışmasın
    await supabase.from('users').update({ fcm_token: null }).eq('fcm_token', fcm_token);

    // Sonra yeni giriş yapan kişiye kaydet
    const { error } = await supabase.from('users').update({ fcm_token }).eq('id', id);

    if (error) {
      console.error(`[FCM-TOKEN] Kayıt hatası (User ${id}):`, error.message);
      return res.status(500).json({ error: error.message });
    }
    
    console.log(`[FCM-TOKEN] Kayıt BAŞARILI (User ${id})`);

    res.json({ message: 'Token kaydedildi.' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// ============================================================
// COMPANIES
// ============================================================

// GET /api/companies - Tüm şirketler (admin görür)
app.get('/api/companies', async (req, res) => {
  try {
    const { data, error } = await supabase.from('companies').select('*').order('name');
    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// ============================================================
// WORKERS
// ============================================================

// GET /api/workers?date=YYYY-MM-DD
// O gün başka bir onaylı/bekleyen vardiyada olan çalışanları işaretle
app.get('/api/workers', async (req, res) => {
  try {
    const { date } = req.query;

    // Tüm çalışanları al
    const { data: workers, error } = await supabase
      .from('users')
      .select('id, name, role')
      .eq('role', 'worker')
      .order('name');

    if (error) return res.status(500).json({ error: error.message });

    // O gün zaten atanmış çalışanları bul
    let busyWorkerIds = [];
    if (date) {
      const { data: busyAssignments } = await supabase
        .from('shift_assignments')
        .select('worker_id, shift_plans!inner(work_date, status)')
        .eq('shift_plans.work_date', date)
        .in('shift_plans.status', ['pending', 'approved']);

      if (busyAssignments) {
        busyWorkerIds = busyAssignments.map(a => a.worker_id);
      }
    }

    const enriched = workers.map(w => ({
      ...w,
      is_busy: busyWorkerIds.includes(w.id)
    }));

    res.json(enriched);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// ============================================================
// SHIFT PLANS
// ============================================================

// POST /api/shift-plans - Yeni plan oluştur (yönetici)
app.post('/api/shift-plans', async (req, res) => {
  try {
    const { company_id, created_by, work_date, start_time, end_time, assignments } = req.body;
    // assignments: [{ worker_id, worker_name, role_in_shift }]

    if (!company_id || !created_by || !work_date || !start_time || !end_time) {
      return res.status(400).json({ error: 'Tüm alanlar zorunludur.' });
    }

    if (!assignments || !assignments.length) {
      return res.status(400).json({ error: 'En az bir çalışan (lider) seçilmelidir.' });
    }

    // === ÖZELLİK 3: Manager sadece kendi şirketine plan oluşturabilir ===
    const { data: creator } = await supabase.from('users').select('role, company_id').eq('id', created_by).single();
    if (creator && creator.role === 'manager') {
      if (creator.company_id !== company_id) {
        return res.status(403).json({ error: 'Yalnızca kendi şirketiniz için plan oluşturabilirsiniz.' });
      }
    }

    const leaderCount = assignments.filter(a => a.role_in_shift === 'leader').length;
    if (leaderCount === 0) return res.status(400).json({ error: 'Her planda en az 1 lider olmalıdır.' });
    if (leaderCount > 1) return res.status(400).json({ error: 'Bir planda yalnızca 1 lider olabilir.' });

    // Çakışma kontrolü (Aynı gün başka onaylı/bekleyen vardiyada mı?)
    const workerIds = assignments.map(a => a.worker_id);
    const { data: conflictCheck } = await supabase
      .from('shift_assignments')
      .select('worker_id, shift_plans!inner(work_date, status)')
      .eq('shift_plans.work_date', work_date)
      .in('shift_plans.status', ['pending', 'approved'])
      .in('worker_id', workerIds);

    if (conflictCheck && conflictCheck.length > 0) {
      const conflictIds = conflictCheck.map(c => c.worker_id);
      const conflictNames = assignments.filter(a => conflictIds.includes(a.worker_id)).map(a => a.worker_name);
      return res.status(400).json({ error: `${conflictNames.join(', ')} kişi(ler) bu tarihte zaten başka bir vardiyada. Lütfen başka bir çalışan seçin.` });
    }

    // === ÖZELLİK 4: Super Admin onay beklemez ===
    let initialStatus = 'pending';
    if (creator && creator.role === 'super_admin') {
      initialStatus = 'approved';
    }

    // Plan oluştur
    const { data: plan, error: planError } = await supabase
      .from('shift_plans')
      .insert([{ company_id, created_by, work_date, start_time, end_time, status: initialStatus }])
      .select()
      .single();

    if (planError) return res.status(500).json({ error: planError.message });

    // Atamaları ekle
    const assignmentRows = assignments.map(a => ({
      shift_plan_id: plan.id,
      worker_id: a.worker_id,
      worker_name: a.worker_name,
      role_in_shift: a.role_in_shift
    }));

    const { error: assignError } = await supabase.from('shift_assignments').insert(assignmentRows);
    if (assignError) return res.status(500).json({ error: assignError.message });

    // Eğer anında onaylandıysa bildirim gönder
    if (initialStatus === 'approved') {
      try {
        console.log(`[FCM] Bildirim gönderilecek worker ID'leri: ${workerIds.join(', ')}`);
        const { data: workersWithTokens, error: tokenErr } = await supabase
          .from('users')
          .select('id, fcm_token')
          .in('id', workerIds);
        
        if (tokenErr) console.error('[FCM] Token sorgulama hatası:', tokenErr.message);
        console.log(`[FCM] Token sorgusu döndü:`, JSON.stringify(workersWithTokens));

        const tokens = (workersWithTokens || []).map(u => u.fcm_token).filter(t => t);
        console.log(`[FCM] Gönderilecek geçerli token sayısı: ${tokens.length}`);
        if (tokens.length > 0) {
          const result = await admin.messaging().sendEachForMulticast({
            notification: {
              title: '📅 Yeni İş Atandı!',
              body: `Ekrem bey size iş ekledi. Uygulamadan detaylara bakabilirsiniz.`
            },
            android: {
              priority: 'high',
              notification: { sound: 'default', channelId: 'high_importance_channel' }
            },
            apns: {
              payload: {
                aps: { sound: 'default', badge: 1, contentAvailable: true }
              }
            },
            tokens: tokens
          });
          console.log(`[FCM] Gönderim sonucu: ${result.successCount} başarı, ${result.failureCount} hata`);
          if (result.failureCount > 0) result.responses.forEach((r, i) => { if (!r.success) console.error(`[FCM] Token ${i} hatası:`, r.error?.message); });
        }
      } catch (fcmErr) {
        console.error('FCM Error on auto-approve:', fcmErr);
      }
    }

    res.json({ 
      message: initialStatus === 'approved' ? 'Vardiya planı oluşturuldu ve otomatik onaylandı.' : 'Vardiya planı oluşturuldu. Ekrem onayı bekleniyor.', 
      plan 
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// GET /api/shift-plans?company_id=X&status=pending
app.get('/api/shift-plans', async (req, res) => {
  try {
    const { company_id, status, created_by } = req.query;

    let query = supabase
      .from('shift_plans')
      .select(`
        id, company_id, work_date, start_time, end_time, status, rejection_note, created_at, created_by,
        companies(name),
        shift_assignments(worker_id, worker_name, role_in_shift, shift_status, actual_start, actual_end, exit_note)
      `)
      .order('work_date', { ascending: true })
      .order('start_time', { ascending: true });

    if (company_id) query = query.eq('company_id', company_id);
    if (status) query = query.eq('status', status);
    if (created_by) query = query.eq('created_by', created_by);

    const { data, error } = await query;
    if (error) return res.status(500).json({ error: error.message });

    res.json(data);
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// PATCH /api/shift-plans/:id/approve - Ekrem onaylar
app.patch('/api/shift-plans/:id/approve', async (req, res) => {
  try {
    const { id } = req.params;
    const { approved_by } = req.body;

    // Sadece super_admin onaylayabilir
    const { data: approver } = await supabase.from('users').select('role').eq('id', approved_by).single();
    if (!approver || approver.role !== 'super_admin') {
      return res.status(403).json({ error: 'Yalnızca Süper Admin onay verebilir.' });
    }

    const { data: updatedPlan, error } = await supabase
      .from('shift_plans')
      .update({ status: 'approved' })
      .eq('id', id)
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });

    // === PUSH BİLDİRİM GÖNDER ===
    try {
      // Bu plana ait çalışanları ve fcm_token'larını al
      const { data: assignments } = await supabase
        .from('shift_assignments')
        .select(`
          worker_id,
          users:worker_id (fcm_token)
        `)
        .eq('shift_plan_id', id);

      if (assignments && assignments.length > 0) {
        const tokens = assignments
          .map(a => a.users?.fcm_token)
          .filter(t => t && t.length > 0);

        if (tokens.length > 0) {
          const message = {
            notification: {
              title: '📅 Yeni Vardiya Onaylandı!',
              body: `${updatedPlan.work_date} tarihindeki vardiyanız onaylandı. Detaylar için uygulamaya bakın.`
            },
            android: {
              priority: 'high',
              notification: { sound: 'default', channelId: 'high_importance_channel' }
            },
            apns: {
              payload: {
                aps: { sound: 'default', badge: 1, contentAvailable: true }
              }
            },
            tokens: tokens
          };

          const response = await admin.messaging().sendEachForMulticast(message);
          console.log(`[FCM] ${response.successCount} mesaj başarıyla gönderildi.`);
        }
      }
    } catch (fcmErr) {
      console.error('FCM Error:', fcmErr);
      // Hata olsa bile ana işlem (onay) tamamlandığı için devam ediyoruz
    }

    res.json({ message: 'Vardiya planı onaylandı!', plan: data });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// PATCH /api/shift-plans/:id/reject - Ekrem reddeder
app.patch('/api/shift-plans/:id/reject', async (req, res) => {
  try {
    const { id } = req.params;
    const { rejected_by, rejection_note } = req.body;

    const { data: rejecter } = await supabase.from('users').select('role').eq('id', rejected_by).single();
    if (!rejecter || rejecter.role !== 'super_admin') {
      return res.status(403).json({ error: 'Yalnızca Süper Admin reddedebilir.' });
    }

    const { data, error } = await supabase
      .from('shift_plans')
      .update({ status: 'rejected', rejection_note: rejection_note || 'Açıklama girilmedi.' })
      .eq('id', id)
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    res.json({ message: 'Vardiya planı reddedildi.', plan: data });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});


// DELETE /api/shift-plans/:id
app.delete('/api/shift-plans/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { deleted_by } = req.body;
    const { data: user } = await supabase.from('users').select('role').eq('id', deleted_by).single();
    if (!user || !['super_admin', 'manager'].includes(user.role)) {
      return res.status(403).json({ error: 'Yetkiniz yok.' });
    }

    // Bildirim için önce işçileri al
    const { data: assignments } = await supabase
      .from('shift_assignments')
      .select('users:worker_id (fcm_token)')
      .eq('shift_plan_id', id);

    const { error } = await supabase.from('shift_plans').delete().eq('id', id);
    if (error) return res.status(500).json({ error: error.message });

    // Bildirimleri gönder
    if (assignments && assignments.length > 0) {
      const tokens = assignments.map(a => a.users?.fcm_token).filter(t => t);
      if (tokens.length > 0) {
        try {
          await admin.messaging().sendEachForMulticast({
            notification: {
              title: '🚫 Plan Silindi',
              body: 'Ekrem bey plan sildi.'
            },
            android: {
              priority: 'high',
              notification: { sound: 'default', channelId: 'high_importance_channel' }
            },
            apns: {
              payload: {
                aps: { sound: 'default', badge: 1, contentAvailable: true }
              }
            },
            tokens: tokens
          });
          console.log(`[FCM] Silme bildirimi ${tokens.length} kişiye gönderildi.`);
        } catch (fcmErr) {
          console.error('[FCM] Silme bildirimi hatası:', fcmErr.message);
        }
      }
    }

    res.json({ message: 'Vardiya planı silindi.' });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// PATCH /api/shift-plans/:id/edit
app.patch('/api/shift-plans/:id/edit', async (req, res) => {
  try {
    const { id } = req.params;
    const { work_date, start_time, end_time, notes } = req.body;
    const updates = { status: 'pending' };
    if (work_date) updates.work_date = work_date;
    if (start_time) updates.start_time = start_time;
    if (end_time) updates.end_time = end_time;
    if (notes !== undefined) updates.notes = notes;
    const { data, error } = await supabase.from('shift_plans').update(updates).eq('id', id).select().single();
    if (error) return res.status(500).json({ error: error.message });
    res.json({ message: 'Plan güncellendi, tekrar onay bekleniyor.', plan: data });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// GET /api/companies/:company_id/plans
app.get('/api/companies/:company_id/plans', async (req, res) => {
  try {
    const { company_id } = req.params;
    const { from_date, to_date } = req.query;
    let query = supabase.from('shift_plans')
      .select('id, company_id, work_date, start_time, end_time, status, rejection_note, notes, created_at, created_by, companies(name), shift_assignments(worker_id, worker_name, role_in_shift, shift_status, actual_start, actual_end, total_hours, exit_note)')
      .eq('company_id', company_id)
      .order('work_date', { ascending: false });
    if (from_date) query = query.gte('work_date', from_date);
    if (to_date) query = query.lte('work_date', to_date);
    const { data, error } = await query;
    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// GET /api/workers/stats/:worker_id
app.get('/api/workers/stats/:worker_id', async (req, res) => {
  try {
    const { worker_id } = req.params;
    const { data: summaries } = await supabase.from('monthly_summaries')
      .select('report_year, report_month, total_hours, total_sessions')
      .eq('employee_id', worker_id).order('report_year', { ascending: false });
    const totalHours = (summaries || []).reduce((s, r) => s + parseFloat(r.total_hours || 0), 0);
    const totalShifts = (summaries || []).reduce((s, r) => s + (r.total_sessions || 0), 0);
    res.json({ monthly_summaries: summaries || [], total_hours: totalHours.toFixed(2), total_shifts: totalShifts });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});
// ============================================================
// WORKER - KENDİ VARDİYALARI
// ============================================================

// GET /api/my-shifts/:worker_id
app.get('/api/my-shifts/:worker_id', async (req, res) => {
  try {
    const { worker_id } = req.params;

    const { data, error } = await supabase
      .from('shift_assignments')
      .select(`
        id, role_in_shift, shift_status, actual_start, actual_end,
        shift_plans!inner(id, work_date, start_time, end_time, status, company_id, companies(name))
      `)
      .eq('worker_id', worker_id)
      .in('shift_plans.status', ['approved'])
      .order('shift_plans(work_date)', { ascending: true });

    if (error) return res.status(500).json({ error: error.message });

    // Flatten for easier frontend use
    const shifts = data.map(a => ({
      assignment_id: a.id,
      role_in_shift: a.role_in_shift,
      shift_status: a.shift_status,
      actual_start: a.actual_start,
      actual_end: a.actual_end,
      plan_id: a.shift_plans.id,
      work_date: a.shift_plans.work_date,
      start_time: a.shift_plans.start_time,
      end_time: a.shift_plans.end_time,
      company_id: a.shift_plans.company_id,
      company_name: a.shift_plans.companies?.name
    }));

    res.json(shifts);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// POST /api/shifts/:assignment_id/start - Mesai başlat
app.post('/api/shifts/:assignment_id/start', async (req, res) => {
  try {
    const { assignment_id } = req.params;
    const { worker_id } = req.body;

    // Güvenlik: Bu atama bu çalışana mı ait?
    const { data: assignment } = await supabase
      .from('shift_assignments')
      .select('worker_id, shift_status, shift_plans!inner(status)')
      .eq('id', assignment_id)
      .single();

    if (!assignment) return res.status(404).json({ error: 'Vardiya bulunamadı.' });
    if (assignment.worker_id !== worker_id) return res.status(403).json({ error: 'Bu vardiya size ait değil.' });
    if (assignment.shift_plans.status !== 'approved') return res.status(400).json({ error: 'Bu vardiya henüz onaylanmamış.' });
    if (assignment.shift_status !== 'assigned') return res.status(400).json({ error: 'Vardiya zaten başlatılmış veya tamamlandı.' });

    const { data, error } = await supabase
      .from('shift_assignments')
      .update({ shift_status: 'active', actual_start: new Date().toISOString() })
      .eq('id', assignment_id)
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    res.json({ message: 'Mesai başlatıldı!', assignment: data });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// POST /api/shifts/:assignment_id/end - Mesai bitir
app.post('/api/shifts/:assignment_id/end', async (req, res) => {
  try {
    const { assignment_id } = req.params;
    const { worker_id, exit_note } = req.body; // === ÖZELLİK 1: exit_note isteğe bağlı ===

    const { data: assignment } = await supabase
      .from('shift_assignments')
      .select('worker_id, shift_status, actual_start, shift_plans!inner(work_date, end_time)')
      .eq('id', assignment_id)
      .single();

    if (!assignment) return res.status(404).json({ error: 'Vardiya bulunamadı.' });
    if (assignment.worker_id !== worker_id) return res.status(403).json({ error: 'Bu vardiya size ait değil.' });
    if (assignment.shift_status !== 'active') return res.status(400).json({ error: 'Aktif bir mesai bulunamadı.' });

    const endTime = new Date();
    const startTime = new Date(assignment.actual_start);
    const totalHours = parseFloat(((endTime - startTime) / (1000 * 60 * 60)).toFixed(4));

    // Planlanan bitiş saatini hesapla (aynı iş günündeki saat)
    const workDate = assignment.shift_plans.work_date; // YYYY-MM-DD
    const plannedEndStr = `${workDate}T${assignment.shift_plans.end_time}`;
    const plannedEnd = new Date(plannedEndStr);
    const diffMinutes = (endTime - plannedEnd) / (1000 * 60); // pozitif = geç, negatif = erken
    const THRESHOLD = 5; // 5 dakikadan fazla erken/geç ise not gerekli

    // Not gerekli mi?
    let noteRequired = Math.abs(diffMinutes) > THRESHOLD;
    let savedNote = null;
    if (exit_note && exit_note.trim()) {
      savedNote = exit_note.trim();
    } else if (noteRequired) {
      // Frontend'den not gelmemişse (güvenlik için backend kontrolü)
      const direction = diffMinutes < 0 ? 'erken' : 'geç';
      savedNote = `[${Math.abs(Math.round(diffMinutes))} dk ${direction} çıkıldı - açıklama girilmedi]`;
    }

    const updateData = { shift_status: 'completed', actual_end: endTime.toISOString(), total_hours: totalHours };
    if (savedNote) updateData.exit_note = savedNote;

    const { data, error } = await supabase
      .from('shift_assignments')
      .update(updateData)
      .eq('id', assignment_id)
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });

    // Aylık özet güncelle
    try {
      const { data: workerInfo } = await supabase.from('users').select('name').eq('id', worker_id).single();
      const workerName = workerInfo?.name || 'Bilinmiyor';
      const year = endTime.getFullYear();
      const month = endTime.getMonth() + 1;

      const { data: summary } = await supabase
        .from('monthly_summaries')
        .select('*')
        .eq('employee_id', worker_id)
        .eq('report_year', year)
        .eq('report_month', month)
        .maybeSingle();

      if (summary) {
        await supabase.from('monthly_summaries').update({
          total_hours: parseFloat(summary.total_hours || 0) + totalHours,
          total_sessions: (summary.total_sessions || 0) + 1
        }).eq('id', summary.id);
      } else {
        await supabase.from('monthly_summaries').insert([{
          employee_id: worker_id,
          employee_name: workerName,
          report_year: year,
          report_month: month,
          total_hours: totalHours,
          total_sessions: 1
        }]);
      }
    } catch (summaryErr) {
      console.error('Monthly summary error:', summaryErr);
    }

    res.json({
      message: 'Mesai tamamlandı!',
      total_hours: totalHours,
      assignment: data,
      note_required: noteRequired,
      diff_minutes: Math.round(diffMinutes)
    });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// === ÖZELLİK 2: PATCH /api/shifts/:assignment_id/adjust - Geriye dönük saat düzenleme ===
app.patch('/api/shifts/:assignment_id/adjust', async (req, res) => {
  try {
    const { assignment_id } = req.params;
    const { adjusted_by, actual_start, actual_end } = req.body;

    if (!adjusted_by) return res.status(400).json({ error: 'adjusted_by zorunludur.' });
    if (!actual_start && !actual_end) return res.status(400).json({ error: 'En az bir saat girilmelidir.' });

    // Sadece super_admin ve manager düzenleyebilir
    const { data: adjuster } = await supabase.from('users').select('role').eq('id', adjusted_by).single();
    if (!adjuster || !['super_admin', 'manager'].includes(adjuster.role)) {
      return res.status(403).json({ error: 'Bu işlem için yetkiniz yok.' });
    }

    const { data: current } = await supabase
      .from('shift_assignments')
      .select('actual_start, actual_end, shift_status')
      .eq('id', assignment_id)
      .single();

    if (!current) return res.status(404).json({ error: 'Atama bulunamadı.' });

    const newStart = actual_start ? new Date(actual_start) : new Date(current.actual_start);
    const newEnd   = actual_end   ? new Date(actual_end)   : new Date(current.actual_end);

    if (newEnd <= newStart) return res.status(400).json({ error: 'Bitiş saati başlangıçtan sonra olmalıdır.' });

    const totalHours = parseFloat(((newEnd - newStart) / (1000 * 60 * 60)).toFixed(4));

    const updateFields = { total_hours: totalHours };
    if (actual_start) updateFields.actual_start = newStart.toISOString();
    if (actual_end)   updateFields.actual_end   = newEnd.toISOString();
    // Tamamlanmış sayılsın
    if (current.shift_status !== 'completed') updateFields.shift_status = 'completed';

    const { data, error } = await supabase
      .from('shift_assignments')
      .update(updateFields)
      .eq('id', assignment_id)
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    res.json({ message: 'Saat güncellendi.', assignment: data, total_hours: totalHours });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// ============================================================
// ADMIN TEST ENDPOINTS (Manuel Rapor Tetikleme)
// ============================================================
app.get('/api/admin/trigger-daily', async (req, res) => {
  await reporter.sendDailyReport();
  res.json({ message: 'Günlük Rapor Maili Tetiklendi!' });
});

app.get('/api/admin/trigger-monthly', async (req, res) => {
  await reporter.sendMonthlyReport();
  res.json({ message: 'Aylık Rapor Maili Tetiklendi!' });
});

// ============================================================
const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Sunucu ${PORT} portunda çalışıyor.`);
});

// ============================================================
// ADMIN - ELEMAN YÖNETİMİ
// ============================================================

// GET /api/admin/workers/:id - ID ile çalışan sorgula (silme doğrulaması için)
app.get('/api/admin/workers/:id', async (req, res) => {
  try {
    const { data, error } = await supabase.from('users').select('id, name, role, company_id').eq('id', req.params.id).single();
    if (error || !data) return res.status(404).json({ error: 'Çalışan bulunamadı.' });
    res.json(data);
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// POST /api/admin/workers - Yeni çalışan ekle (sadece Ekrem)
app.post('/api/admin/workers', async (req, res) => {
  try {
    const { id, name, pin_code, role = 'worker', company_id } = req.body;
    if (!id || !name || !pin_code) return res.status(400).json({ error: 'ID, isim ve PIN zorunludur.' });
    const { data: existing } = await supabase.from('users').select('id').eq('id', id).single();
    if (existing) return res.status(400).json({ error: 'Bu ID zaten kullanımda.' });
    const insertData = { id, name, pin_code, role };
    if (company_id) insertData.company_id = company_id;
    const { data, error } = await supabase.from('users').insert(insertData).select().single();
    if (error) return res.status(500).json({ error: error.message });
    res.status(201).json({ message: 'Çalışan eklendi.', user: data });
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// DELETE /api/admin/workers/:id - Çalışan sil (Supabase cascade ile tüm kayıtları siler)
app.delete('/api/admin/workers/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { data: user } = await supabase.from('users').select('role').eq('id', id).single();
    if (!user) return res.status(404).json({ error: 'Çalışan bulunamadı.' });
    if (user.role === 'super_admin') return res.status(403).json({ error: 'Süper Admin silinemez.' });
    const { error } = await supabase.from('users').delete().eq('id', id);
    if (error) return res.status(500).json({ error: error.message });
    res.json({ message: 'Çalışan silindi.' });
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// GET /api/today/activity - Günlük takip (kim nerede çalışıyor)
app.get('/api/today/activity', async (req, res) => {
  try {
    const date = req.query.date || new Date().toISOString().split('T')[0];
    const { data, error } = await supabase
      .from('shift_assignments')
      .select(`
        worker_id, worker_name, role_in_shift, shift_status, actual_start, actual_end, exit_note,
        shift_plans!inner(work_date, start_time, end_time, status, company_id, companies(name))
      `)
      .eq('shift_plans.work_date', date)
      .eq('shift_plans.status', 'approved');
    if (error) return res.status(500).json({ error: error.message });
    const rows = (data || []).map(a => ({
      worker_id:    a.worker_id,
      worker_name:  a.worker_name,
      role_in_shift: a.role_in_shift,
      shift_status: a.shift_status,
      actual_start: a.actual_start,
      actual_end:   a.actual_end,
      exit_note:    a.exit_note,
      plan_start:   a.shift_plans?.start_time,
      plan_end:     a.shift_plans?.end_time,
      company_id:   a.shift_plans?.company_id,
      company_name: a.shift_plans?.companies?.name,
    }));
    res.json(rows);
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});
