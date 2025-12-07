
import '../styles/globals.css';

import Header from '../components/Header';

import Footer from '../components/Footer';

import { AuthProvider, useAuth } from '../context/AuthContext';

function AppWrapper({ Component, pageProps }) {

  const { loading } = useAuth();

  if (loading) {

    return <div style={{padding:40,textAlign:'center'}}>در حال بارگذاری...</div>;

  }

  return (

    <>

      <Header />

      <Component {...pageProps} />

      <Footer />

    </>

  );

}

export default function MyApp(props) {

  return (

    <AuthProvider>

      <AppWrapper {...props} />

    </AuthProvider>

  );

}

