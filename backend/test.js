import { supabase } from './supabaseClient.js';

async function testConnection() {
  console.log('جاري اختبار الاتصال بـ Supabase...');

  // قم بتغيير 'profiles' باسم أي جدول أنشأته
  const { data, error } = await supabase.from('profiles').select('*').limit(1);

  if (error) {
    console.log('⚠️ استجابة Supabase:', error.message);
  } else {
    console.log('✅ تم جلب البيانات بنجاح! النتيجة:', data);
  }
}

testConnection();
